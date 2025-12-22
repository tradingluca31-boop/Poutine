//+------------------------------------------------------------------+
//|                                                      Poutine.mq5 |
//|                    INSTITUTIONAL GRADE LONDON BREAKOUT EA        |
//|                   https://github.com/tradingluca31-boop/Poutine  |
//+------------------------------------------------------------------+
#property copyright "Poutine EA - Institutional Grade"
#property link      "https://github.com/tradingluca31-boop/Poutine"
#property version   "2.00"
#property description "=== POUTINE EA v2.0 ==="
#property description "Institutional Grade London Breakout for XAUUSD"
#property description "Based on Asian Range Box + Smart Money Concepts"
#property description "FTMO/Prop Firm Compliant | No Martingale | No Grid"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| ENUMS                                                             |
//+------------------------------------------------------------------+
enum ENUM_SL_TYPE
{
    SL_AGGRESSIVE,    // Aggressive (Middle of Box)
    SL_CONSERVATIVE,  // Conservative (Opposite Side)
    SL_ATR_BASED      // ATR-Based Dynamic
};

enum ENUM_ENTRY_TYPE
{
    ENTRY_SAFE,       // Safe (Wait for candle close)
    ENTRY_AGGRESSIVE  // Aggressive (Immediate breakout)
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "══════════ RISK MANAGEMENT ══════════"
input double   InpRiskPercent       = 1.0;              // Risk % Per Trade
input double   InpRiskReward        = 3.0;              // Risk:Reward Ratio
input double   InpMaxDailyLossPct   = 4.0;              // Max Daily Loss % (FTMO: 5%)
input double   InpMaxTotalDDPct     = 8.0;              // Max Total Drawdown % (FTMO: 10%)
input bool     InpUseFTMOProtection = true;             // Enable FTMO Protection

input group "══════════ TRADE SETTINGS ══════════"
input int      InpMagicNumber       = 202401;           // Magic Number
input ENUM_SL_TYPE InpSLType        = SL_AGGRESSIVE;    // Stop Loss Type
input ENUM_ENTRY_TYPE InpEntryType  = ENTRY_SAFE;       // Entry Type
input bool     InpUseTrailingStop   = true;             // Use Trailing Stop
input double   InpTrailingATRMult   = 1.5;              // Trailing Stop ATR Multiplier

input group "══════════ SESSION TIMES (GMT) ══════════"
input int      InpAsianStartHour    = 0;                // Asian Range Start (GMT)
input int      InpAsianEndHour      = 7;                // Asian Range End (GMT)
input int      InpLondonStartHour   = 7;                // London Entry Start (GMT)
input int      InpLondonEndHour     = 10;               // London Entry End (GMT)
input int      InpForceCloseHour    = 22;               // Force Close Before (GMT)

input group "══════════ BREAKOUT FILTERS ══════════"
input ENUM_TIMEFRAMES InpConfirmTF  = PERIOD_M15;       // Confirmation Timeframe
input int      InpMinRangePts       = 300;              // Min Asian Range (points)
input int      InpMaxRangePts       = 2500;             // Max Asian Range (points)
input int      InpBreakoutBuffer    = 50;               // Breakout Buffer (points)
input int      InpMaxSpread         = 40;               // Max Spread (points)

input group "══════════ SMART MONEY FILTERS ══════════"
input bool     InpUseLiquiditySweep = true;             // Detect Liquidity Sweeps
input int      InpSweepBuffer       = 100;              // Sweep Detection Buffer (pts)
input bool     InpUseATRFilter      = true;             // Use ATR Volatility Filter
input int      InpATRPeriod         = 14;               // ATR Period
input double   InpMinATRMult        = 0.3;              // Min ATR Multiplier

input group "══════════ DISPLAY ══════════"
input bool     InpShowPanel         = true;             // Show Info Panel
input bool     InpDrawBoxes         = true;             // Draw Asian Range Box
input color    InpBoxColorBull      = clrLime;          // Bullish Breakout Color
input color    InpBoxColorBear      = clrRed;           // Bearish Breakout Color
input color    InpBoxColorNeutral   = clrGray;          // Neutral Box Color

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
CTrade         trade;
CPositionInfo  posInfo;
CAccountInfo   accInfo;

// Session data
double         g_AsianHigh = 0;
double         g_AsianLow = 0;
double         g_AsianMid = 0;
double         g_AsianRange = 0;
bool           g_RangeCalculated = false;

// Trade management
bool           g_TradeTakenToday = false;
datetime       g_LastTradeDate = 0;
int            g_BrokerGMTOffset = 0;
double         g_DailyStartBalance = 0;
double         g_InitialBalance = 0;

// Smart Money tracking
bool           g_LiquiditySweepDetected = false;
int            g_SweepDirection = 0;  // 1 = swept lows (bullish), -1 = swept highs (bearish)

// ATR handle
int            g_ATRHandle = INVALID_HANDLE;

// Statistics
int            g_TotalTrades = 0;
int            g_WinTrades = 0;
int            g_LossTrades = 0;
double         g_TotalProfit = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    // Validate symbol
    string symbol = Symbol();
    if(StringFind(symbol, "XAU") < 0 && StringFind(symbol, "GOLD") < 0)
    {
        Print("⚠️ WARNING: Poutine EA is optimized for XAUUSD/GOLD only!");
        Print("Current symbol: ", symbol);
    }

    // Initialize trade object
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetDeviationInPoints(50);
    trade.SetTypeFilling(ORDER_FILLING_IOC);

    // Initialize ATR handle
    g_ATRHandle = iATR(Symbol(), InpConfirmTF, InpATRPeriod);
    if(g_ATRHandle == INVALID_HANDLE)
    {
        Print("❌ Failed to create ATR indicator");
        return(INIT_FAILED);
    }

    // Calculate broker GMT offset
    g_BrokerGMTOffset = CalculateBrokerGMTOffset();

    // Store initial balance
    g_InitialBalance = accInfo.Balance();
    g_DailyStartBalance = g_InitialBalance;

    // Print initialization info
    PrintInitInfo();

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release ATR handle
    if(g_ATRHandle != INVALID_HANDLE)
        IndicatorRelease(g_ATRHandle);

    // Clean up chart objects
    ObjectsDeleteAll(0, "Poutine_");
    Comment("");

    Print("═══════════════════════════════════════");
    Print("POUTINE EA STOPPED");
    Print("Total Trades: ", g_TotalTrades);
    Print("Win Rate: ", g_TotalTrades > 0 ? DoubleToString((double)g_WinTrades / g_TotalTrades * 100, 1) : "0", "%");
    Print("Total P/L: $", DoubleToString(g_TotalProfit, 2));
    Print("═══════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Get current GMT time
    int gmtHour, gmtMinute;
    GetGMTTime(gmtHour, gmtMinute);

    // Check for new day and reset
    CheckNewDay();

    // FTMO Protection Check
    if(InpUseFTMOProtection && !CheckFTMOLimits())
    {
        if(InpShowPanel) UpdatePanel("⛔ FTMO LIMIT REACHED - TRADING DISABLED");
        return;
    }

    // Phase 1: Calculate Asian Range (00:00 - 07:00 GMT)
    if(gmtHour >= InpAsianStartHour && gmtHour < InpAsianEndHour)
    {
        CalculateAsianRange();
        if(InpShowPanel) UpdatePanel("📊 CALCULATING ASIAN RANGE...");
    }

    // Phase 2: London Breakout Entry (07:00 - 10:00 GMT)
    if(gmtHour >= InpLondonStartHour && gmtHour < InpLondonEndHour)
    {
        if(g_RangeCalculated && !g_TradeTakenToday && !HasOpenPosition())
        {
            if(InpShowPanel) UpdatePanel("🎯 LONDON OPEN - SCANNING FOR BREAKOUT...");

            // Smart Money: Check for liquidity sweep first
            if(InpUseLiquiditySweep)
            {
                DetectLiquiditySweep();
            }

            CheckForBreakout();
        }
        else if(g_TradeTakenToday)
        {
            if(InpShowPanel) UpdatePanel("✅ TRADE TAKEN - MANAGING POSITION");
        }
    }

    // Phase 3: Trade Management
    if(HasOpenPosition())
    {
        ManagePosition();
        if(InpShowPanel) UpdatePanel("📈 POSITION ACTIVE - MANAGING...");
    }

    // Phase 4: Force Close Before Asian (22:00 GMT)
    if(gmtHour >= InpForceCloseHour)
    {
        ForceCloseAllPositions("End of Day");
        if(InpShowPanel) UpdatePanel("🌙 SESSION ENDED - WAITING FOR NEW DAY");
    }

    // Update chart display
    if(InpDrawBoxes && g_RangeCalculated)
    {
        DrawAsianRangeBox();
    }
}

//+------------------------------------------------------------------+
//| OnTrade - Track closed positions                                  |
//+------------------------------------------------------------------+
void OnTrade()
{
    static int lastHistoryTotal = 0;
    int currentHistoryTotal = HistoryDealsTotal();

    if(currentHistoryTotal > lastHistoryTotal)
    {
        // Check last closed deal
        HistorySelect(0, TimeCurrent());
        int total = HistoryDealsTotal();

        for(int i = total - 1; i >= lastHistoryTotal; i--)
        {
            ulong ticket = HistoryDealGetTicket(i);
            if(ticket > 0)
            {
                if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber)
                {
                    if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
                    {
                        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                        g_TotalProfit += profit;
                        g_TotalTrades++;

                        if(profit > 0)
                            g_WinTrades++;
                        else if(profit < 0)
                            g_LossTrades++;

                        Print("═══ TRADE CLOSED ═══");
                        Print("Profit: $", DoubleToString(profit, 2));
                        Print("Total Trades: ", g_TotalTrades, " | Win Rate: ",
                              DoubleToString((double)g_WinTrades / g_TotalTrades * 100, 1), "%");
                    }
                }
            }
        }
    }
    lastHistoryTotal = currentHistoryTotal;
}

//+------------------------------------------------------------------+
//| Calculate Asian Session Range                                     |
//+------------------------------------------------------------------+
void CalculateAsianRange()
{
    if(g_RangeCalculated) return;

    datetime currentTime = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(currentTime, dt);

    // Calculate Asian session start time
    datetime todayStart = StringToTime(TimeToString(currentTime, TIME_DATE));
    datetime asianStart = todayStart + (InpAsianStartHour + g_BrokerGMTOffset) * 3600;

    // Handle day boundary
    if(InpAsianStartHour + g_BrokerGMTOffset >= 24)
        asianStart -= 86400;
    if(InpAsianStartHour + g_BrokerGMTOffset < 0)
        asianStart += 86400;

    double high = 0;
    double low = DBL_MAX;
    int barsFound = 0;

    // Get bars in Asian session
    int totalBars = Bars(Symbol(), InpConfirmTF);

    for(int i = 0; i < MathMin(totalBars, 500); i++)
    {
        datetime barTime = iTime(Symbol(), InpConfirmTF, i);

        if(barTime < asianStart)
            break;

        double barHigh = iHigh(Symbol(), InpConfirmTF, i);
        double barLow = iLow(Symbol(), InpConfirmTF, i);

        if(barHigh > high) high = barHigh;
        if(barLow < low) low = barLow;
        barsFound++;
    }

    if(barsFound >= 4 && high > 0 && low < DBL_MAX && low < high)
    {
        g_AsianHigh = high;
        g_AsianLow = low;
        g_AsianMid = (high + low) / 2;
        g_AsianRange = (high - low) / _Point;

        Print("═══ ASIAN RANGE CALCULATED ═══");
        Print("High: ", DoubleToString(g_AsianHigh, _Digits));
        Print("Low: ", DoubleToString(g_AsianLow, _Digits));
        Print("Range: ", DoubleToString(g_AsianRange, 0), " points");
    }
}

//+------------------------------------------------------------------+
//| Mark range as finalized at London open                            |
//+------------------------------------------------------------------+
void FinalizeAsianRange()
{
    if(g_AsianHigh > 0 && g_AsianLow > 0 && !g_RangeCalculated)
    {
        g_AsianRange = (g_AsianHigh - g_AsianLow) / _Point;
        g_RangeCalculated = true;
        Print("✅ Asian Range Finalized: ", DoubleToString(g_AsianRange, 0), " points");
    }
}

//+------------------------------------------------------------------+
//| Detect Institutional Liquidity Sweep                              |
//+------------------------------------------------------------------+
void DetectLiquiditySweep()
{
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double sweepBuffer = InpSweepBuffer * _Point;

    // Check if price swept below Asian Low then reversed (bullish sweep)
    if(currentPrice < g_AsianLow - sweepBuffer)
    {
        // Price is below Asian low - potential sweep in progress
        g_LiquiditySweepDetected = false;
    }
    else if(currentPrice > g_AsianLow && currentPrice < g_AsianMid)
    {
        // Price returned inside range after being below - bullish sweep confirmed
        double recentLow = iLow(Symbol(), InpConfirmTF, 1);
        if(recentLow < g_AsianLow)
        {
            g_LiquiditySweepDetected = true;
            g_SweepDirection = 1;  // Bullish
            Print("🎯 LIQUIDITY SWEEP DETECTED: Bullish (swept lows)");
        }
    }

    // Check if price swept above Asian High then reversed (bearish sweep)
    if(currentPrice > g_AsianHigh + sweepBuffer)
    {
        g_LiquiditySweepDetected = false;
    }
    else if(currentPrice < g_AsianHigh && currentPrice > g_AsianMid)
    {
        double recentHigh = iHigh(Symbol(), InpConfirmTF, 1);
        if(recentHigh > g_AsianHigh)
        {
            g_LiquiditySweepDetected = true;
            g_SweepDirection = -1;  // Bearish
            Print("🎯 LIQUIDITY SWEEP DETECTED: Bearish (swept highs)");
        }
    }
}

//+------------------------------------------------------------------+
//| Check for Breakout Entry                                          |
//+------------------------------------------------------------------+
void CheckForBreakout()
{
    // Finalize range if not done
    if(!g_RangeCalculated)
    {
        FinalizeAsianRange();
    }

    if(!g_RangeCalculated) return;

    // Validate range size
    if(g_AsianRange < InpMinRangePts)
    {
        Print("⚠️ Range too small: ", g_AsianRange, " < ", InpMinRangePts);
        return;
    }

    if(g_AsianRange > InpMaxRangePts)
    {
        Print("⚠️ Range too large: ", g_AsianRange, " > ", InpMaxRangePts);
        return;
    }

    // Check spread
    double spread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
    if(spread > InpMaxSpread)
    {
        Print("⚠️ Spread too high: ", spread);
        return;
    }

    // ATR Filter
    if(InpUseATRFilter)
    {
        double atr = GetATR();
        double minATR = (g_AsianHigh - g_AsianLow) * InpMinATRMult;

        if(atr < minATR)
        {
            Print("⚠️ ATR filter failed: ", atr, " < ", minATR);
            return;
        }
    }

    // Pre-trade margin check
    if(!CheckMarginForTrade())
    {
        Print("❌ Insufficient margin for trade");
        return;
    }

    double buffer = InpBreakoutBuffer * _Point;
    bool buySignal = false;
    bool sellSignal = false;

    if(InpEntryType == ENTRY_SAFE)
    {
        // Safe entry: Wait for candle CLOSE outside range
        double close1 = iClose(Symbol(), InpConfirmTF, 1);
        double open1 = iOpen(Symbol(), InpConfirmTF, 1);

        // Bullish breakout: Candle closes above Asian High
        if(close1 > g_AsianHigh + buffer && close1 > open1)
        {
            buySignal = true;
        }
        // Bearish breakout: Candle closes below Asian Low
        else if(close1 < g_AsianLow - buffer && close1 < open1)
        {
            sellSignal = true;
        }
    }
    else // ENTRY_AGGRESSIVE
    {
        double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

        if(ask > g_AsianHigh + buffer)
            buySignal = true;
        else if(bid < g_AsianLow - buffer)
            sellSignal = true;
    }

    // Smart Money confirmation
    if(InpUseLiquiditySweep && g_LiquiditySweepDetected)
    {
        // Only trade in direction of sweep
        if(g_SweepDirection == 1 && sellSignal)
        {
            Print("⚠️ Ignoring SELL - Bullish liquidity sweep detected");
            sellSignal = false;
        }
        else if(g_SweepDirection == -1 && buySignal)
        {
            Print("⚠️ Ignoring BUY - Bearish liquidity sweep detected");
            buySignal = false;
        }
    }

    // Execute trade
    if(buySignal)
    {
        ExecuteTrade(ORDER_TYPE_BUY);
    }
    else if(sellSignal)
    {
        ExecuteTrade(ORDER_TYPE_SELL);
    }
}

//+------------------------------------------------------------------+
//| Execute Trade                                                     |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType)
{
    double entryPrice, slPrice, tpPrice, slDistance;

    if(orderType == ORDER_TYPE_BUY)
    {
        entryPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

        // Calculate SL based on type
        switch(InpSLType)
        {
            case SL_AGGRESSIVE:
                slPrice = g_AsianMid;
                break;
            case SL_CONSERVATIVE:
                slPrice = g_AsianLow - InpBreakoutBuffer * _Point;
                break;
            case SL_ATR_BASED:
                slPrice = entryPrice - GetATR() * 2;
                break;
        }

        slDistance = entryPrice - slPrice;
        tpPrice = entryPrice + (slDistance * InpRiskReward);
    }
    else // SELL
    {
        entryPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);

        switch(InpSLType)
        {
            case SL_AGGRESSIVE:
                slPrice = g_AsianMid;
                break;
            case SL_CONSERVATIVE:
                slPrice = g_AsianHigh + InpBreakoutBuffer * _Point;
                break;
            case SL_ATR_BASED:
                slPrice = entryPrice + GetATR() * 2;
                break;
        }

        slDistance = slPrice - entryPrice;
        tpPrice = entryPrice - (slDistance * InpRiskReward);
    }

    // Calculate lot size
    double lotSize = CalculateLotSize(slDistance);

    if(lotSize <= 0)
    {
        Print("❌ Invalid lot size");
        return;
    }

    // Normalize prices
    slPrice = NormalizeDouble(slPrice, _Digits);
    tpPrice = NormalizeDouble(tpPrice, _Digits);
    entryPrice = NormalizeDouble(entryPrice, _Digits);

    string comment = StringFormat("Poutine_%s_R%.1f",
                                  orderType == ORDER_TYPE_BUY ? "BUY" : "SELL",
                                  InpRiskReward);

    bool success = false;

    if(orderType == ORDER_TYPE_BUY)
        success = trade.Buy(lotSize, Symbol(), entryPrice, slPrice, tpPrice, comment);
    else
        success = trade.Sell(lotSize, Symbol(), entryPrice, slPrice, tpPrice, comment);

    if(success)
    {
        g_TradeTakenToday = true;

        Print("═══════════════════════════════════════");
        Print("✅ ", orderType == ORDER_TYPE_BUY ? "BUY" : "SELL", " ORDER EXECUTED");
        Print("Entry: ", DoubleToString(entryPrice, _Digits));
        Print("SL: ", DoubleToString(slPrice, _Digits), " (", DoubleToString(slDistance / _Point, 0), " pts)");
        Print("TP: ", DoubleToString(tpPrice, _Digits), " (R:", InpRiskReward, ")");
        Print("Lot: ", DoubleToString(lotSize, 2), " | Risk: ", InpRiskPercent, "%");
        Print("Asian Range: H=", DoubleToString(g_AsianHigh, _Digits),
              " L=", DoubleToString(g_AsianLow, _Digits));
        Print("═══════════════════════════════════════");
    }
    else
    {
        Print("❌ Order failed! Error: ", GetLastError(), " - ", trade.ResultComment());
    }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size Based on Risk                                  |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistance)
{
    if(slDistance <= 0) return 0;

    double balance = accInfo.Balance();
    double riskAmount = balance * (InpRiskPercent / 100.0);

    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);

    if(tickSize == 0 || tickValue == 0) return 0;

    double slTicks = slDistance / tickSize;
    double lotSize = riskAmount / (slTicks * tickValue);

    // Normalize to broker limits
    double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));

    return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Manage Open Position                                              |
//+------------------------------------------------------------------+
void ManagePosition()
{
    if(!InpUseTrailingStop) return;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;

        if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;

        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentTP = PositionGetDouble(POSITION_TP);
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

        double atr = GetATR();
        double trailDistance = atr * InpTrailingATRMult;
        double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

        double newSL = 0;

        if(posType == POSITION_TYPE_BUY)
        {
            // Trail SL for longs
            double potentialSL = bid - trailDistance;

            // Only trail if price moved in our favor and new SL is better
            if(potentialSL > openPrice && potentialSL > currentSL)
            {
                newSL = NormalizeDouble(potentialSL, _Digits);
            }
        }
        else // POSITION_TYPE_SELL
        {
            // Trail SL for shorts
            double potentialSL = ask + trailDistance;

            if(potentialSL < openPrice && (currentSL == 0 || potentialSL < currentSL))
            {
                newSL = NormalizeDouble(potentialSL, _Digits);
            }
        }

        // Modify if new SL is valid
        if(newSL > 0 && newSL != currentSL)
        {
            if(trade.PositionModify(ticket, newSL, currentTP))
            {
                Print("📈 Trailing Stop moved to: ", DoubleToString(newSL, _Digits));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Force Close All Positions                                         |
//+------------------------------------------------------------------+
void ForceCloseAllPositions(string reason)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;

        if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;

        if(trade.PositionClose(ticket))
        {
            Print("🔒 Position closed: ", reason);
        }
    }
}

//+------------------------------------------------------------------+
//| Check FTMO Daily/Total Limits                                     |
//+------------------------------------------------------------------+
bool CheckFTMOLimits()
{
    double currentBalance = accInfo.Balance();
    double currentEquity = accInfo.Equity();

    // Check daily loss
    double dailyLoss = g_DailyStartBalance - currentEquity;
    double dailyLossPct = (dailyLoss / g_DailyStartBalance) * 100;

    if(dailyLossPct >= InpMaxDailyLossPct)
    {
        Print("⛔ FTMO Daily Loss Limit Reached: ", DoubleToString(dailyLossPct, 2), "%");
        ForceCloseAllPositions("FTMO Daily Limit");
        return false;
    }

    // Check total drawdown
    double totalDD = g_InitialBalance - currentEquity;
    double totalDDPct = (totalDD / g_InitialBalance) * 100;

    if(totalDDPct >= InpMaxTotalDDPct)
    {
        Print("⛔ FTMO Total Drawdown Limit Reached: ", DoubleToString(totalDDPct, 2), "%");
        ForceCloseAllPositions("FTMO Total DD Limit");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check Margin for Trade                                            |
//+------------------------------------------------------------------+
bool CheckMarginForTrade()
{
    double freeMargin = accInfo.FreeMargin();
    double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);

    double marginRequired;
    if(!OrderCalcMargin(ORDER_TYPE_BUY, Symbol(), minLot,
                        SymbolInfoDouble(Symbol(), SYMBOL_ASK), marginRequired))
    {
        return false;
    }

    // Require at least 2x margin for safety
    return freeMargin >= marginRequired * 2;
}

//+------------------------------------------------------------------+
//| Check for New Day                                                 |
//+------------------------------------------------------------------+
void CheckNewDay()
{
    datetime currentTime = TimeCurrent();
    datetime today = StringToTime(TimeToString(currentTime, TIME_DATE));

    if(g_LastTradeDate != today)
    {
        // New day - reset variables
        g_LastTradeDate = today;
        g_DailyStartBalance = accInfo.Balance();

        ResetDailyVariables();

        Print("═══════════════════════════════════════");
        Print("🌅 NEW TRADING DAY STARTED");
        Print("Date: ", TimeToString(today, TIME_DATE));
        Print("Starting Balance: $", DoubleToString(g_DailyStartBalance, 2));
        Print("═══════════════════════════════════════");
    }
}

//+------------------------------------------------------------------+
//| Reset Daily Variables                                             |
//+------------------------------------------------------------------+
void ResetDailyVariables()
{
    g_AsianHigh = 0;
    g_AsianLow = 0;
    g_AsianMid = 0;
    g_AsianRange = 0;
    g_RangeCalculated = false;
    g_TradeTakenToday = false;
    g_LiquiditySweepDetected = false;
    g_SweepDirection = 0;

    // Clean old chart objects
    ObjectsDeleteAll(0, "Poutine_");
}

//+------------------------------------------------------------------+
//| Get ATR Value                                                     |
//+------------------------------------------------------------------+
double GetATR()
{
    double atr[];
    ArraySetAsSeries(atr, true);

    if(CopyBuffer(g_ATRHandle, 0, 0, 1, atr) <= 0)
        return 0;

    return atr[0];
}

//+------------------------------------------------------------------+
//| Calculate Broker GMT Offset                                       |
//+------------------------------------------------------------------+
int CalculateBrokerGMTOffset()
{
    datetime brokerTime = TimeCurrent();
    datetime gmtTime = TimeGMT();

    // Handle weekend case
    if(gmtTime == 0) return 0;

    int offset = (int)((brokerTime - gmtTime) / 3600);

    // Clamp to reasonable range
    if(offset < -12) offset = -12;
    if(offset > 14) offset = 14;

    return offset;
}

//+------------------------------------------------------------------+
//| Get GMT Time                                                      |
//+------------------------------------------------------------------+
void GetGMTTime(int &hour, int &minute)
{
    datetime currentTime = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(currentTime, dt);

    hour = (dt.hour - g_BrokerGMTOffset + 24) % 24;
    minute = dt.min;
}

//+------------------------------------------------------------------+
//| Check if Position is Open                                         |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
               PositionGetString(POSITION_SYMBOL) == Symbol())
            {
                return true;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Draw Asian Range Box                                              |
//+------------------------------------------------------------------+
void DrawAsianRangeBox()
{
    datetime currentTime = TimeCurrent();
    datetime todayStart = StringToTime(TimeToString(currentTime, TIME_DATE));

    datetime boxStart = todayStart + (InpAsianStartHour + g_BrokerGMTOffset) * 3600;
    datetime boxEnd = todayStart + (InpForceCloseHour + g_BrokerGMTOffset) * 3600;

    string boxName = "Poutine_AsianBox";
    string highName = "Poutine_High";
    string lowName = "Poutine_Low";
    string midName = "Poutine_Mid";

    // Draw rectangle for Asian range
    ObjectDelete(0, boxName);
    ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, boxStart, g_AsianHigh, boxEnd, g_AsianLow);
    ObjectSetInteger(0, boxName, OBJPROP_COLOR, InpBoxColorNeutral);
    ObjectSetInteger(0, boxName, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, boxName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, boxName, OBJPROP_BACK, true);
    ObjectSetInteger(0, boxName, OBJPROP_FILL, true);
    ObjectSetInteger(0, boxName, OBJPROP_COLOR, clrDarkSlateGray);

    // High line
    ObjectDelete(0, highName);
    ObjectCreate(0, highName, OBJ_HLINE, 0, 0, g_AsianHigh);
    ObjectSetInteger(0, highName, OBJPROP_COLOR, InpBoxColorBull);
    ObjectSetInteger(0, highName, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(0, highName, OBJPROP_WIDTH, 2);

    // Low line
    ObjectDelete(0, lowName);
    ObjectCreate(0, lowName, OBJ_HLINE, 0, 0, g_AsianLow);
    ObjectSetInteger(0, lowName, OBJPROP_COLOR, InpBoxColorBear);
    ObjectSetInteger(0, lowName, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(0, lowName, OBJPROP_WIDTH, 2);

    // Mid line (SL reference)
    ObjectDelete(0, midName);
    ObjectCreate(0, midName, OBJ_HLINE, 0, 0, g_AsianMid);
    ObjectSetInteger(0, midName, OBJPROP_COLOR, clrYellow);
    ObjectSetInteger(0, midName, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, midName, OBJPROP_WIDTH, 1);
}

//+------------------------------------------------------------------+
//| Update Info Panel                                                 |
//+------------------------------------------------------------------+
void UpdatePanel(string status)
{
    int gmtHour, gmtMinute;
    GetGMTTime(gmtHour, gmtMinute);

    double equity = accInfo.Equity();
    double dailyPL = equity - g_DailyStartBalance;
    double dailyPLPct = g_DailyStartBalance > 0 ? (dailyPL / g_DailyStartBalance) * 100 : 0;

    string info = "\n";
    info += "╔═══════════════════════════════════════════╗\n";
    info += "║       POUTINE EA v2.0 - INSTITUTIONAL     ║\n";
    info += "║         London Breakout Strategy          ║\n";
    info += "╠═══════════════════════════════════════════╣\n";
    info += "║ " + status + "\n";
    info += "╠═══════════════════════════════════════════╣\n";
    info += "║ GMT Time: " + IntegerToString(gmtHour) + ":" +
            (gmtMinute < 10 ? "0" : "") + IntegerToString(gmtMinute) + "\n";
    info += "╠═══════════════════════════════════════════╣\n";
    info += "║ ASIAN RANGE:\n";
    info += "║   High: " + DoubleToString(g_AsianHigh, _Digits) + "\n";
    info += "║   Low:  " + DoubleToString(g_AsianLow, _Digits) + "\n";
    info += "║   Mid:  " + DoubleToString(g_AsianMid, _Digits) + "\n";
    info += "║   Size: " + DoubleToString(g_AsianRange, 0) + " pts\n";
    info += "╠═══════════════════════════════════════════╣\n";
    info += "║ ACCOUNT:\n";
    info += "║   Equity: $" + DoubleToString(equity, 2) + "\n";
    info += "║   Daily P/L: " + (dailyPL >= 0 ? "+" : "") +
            DoubleToString(dailyPL, 2) + " (" +
            (dailyPLPct >= 0 ? "+" : "") + DoubleToString(dailyPLPct, 2) + "%)\n";
    info += "╠═══════════════════════════════════════════╣\n";
    info += "║ STATS:\n";
    info += "║   Total: " + IntegerToString(g_TotalTrades) +
            " | Win: " + IntegerToString(g_WinTrades) +
            " | Loss: " + IntegerToString(g_LossTrades) + "\n";
    info += "║   Win Rate: " + (g_TotalTrades > 0 ?
            DoubleToString((double)g_WinTrades / g_TotalTrades * 100, 1) : "0") + "%\n";
    info += "╠═══════════════════════════════════════════╣\n";
    info += "║ Risk: " + DoubleToString(InpRiskPercent, 1) +
            "% | R:R = 1:" + DoubleToString(InpRiskReward, 1) + "\n";
    info += "║ Trade Today: " + (g_TradeTakenToday ? "YES ✓" : "NO") + "\n";
    info += "║ Position: " + (HasOpenPosition() ? "OPEN 📈" : "NONE") + "\n";
    info += "╚═══════════════════════════════════════════╝\n";

    Comment(info);
}

//+------------------------------------------------------------------+
//| Print Initialization Info                                         |
//+------------------------------------------------------------------+
void PrintInitInfo()
{
    Print("═══════════════════════════════════════════════════");
    Print("     POUTINE EA v2.0 - INSTITUTIONAL GRADE");
    Print("        London Breakout | Asian Range Box");
    Print("═══════════════════════════════════════════════════");
    Print("Symbol: ", Symbol());
    Print("Timeframe: ", EnumToString(InpConfirmTF));
    Print("Risk: ", InpRiskPercent, "% | R:R = 1:", InpRiskReward);
    Print("Magic: ", InpMagicNumber);
    Print("Broker GMT Offset: ", g_BrokerGMTOffset, "h");
    Print("═══════════════════════════════════════════════════");
    Print("SESSION TIMES (GMT):");
    Print("  Asian Range: ", InpAsianStartHour, ":00 - ", InpAsianEndHour, ":00");
    Print("  London Entry: ", InpLondonStartHour, ":00 - ", InpLondonEndHour, ":00");
    Print("  Force Close: ", InpForceCloseHour, ":00");
    Print("═══════════════════════════════════════════════════");
    Print("FILTERS:");
    Print("  Range: ", InpMinRangePts, " - ", InpMaxRangePts, " pts");
    Print("  Max Spread: ", InpMaxSpread, " pts");
    Print("  ATR Filter: ", InpUseATRFilter ? "ON" : "OFF");
    Print("  Liquidity Sweep: ", InpUseLiquiditySweep ? "ON" : "OFF");
    Print("═══════════════════════════════════════════════════");
    Print("FTMO PROTECTION: ", InpUseFTMOProtection ? "ENABLED" : "DISABLED");
    Print("  Max Daily Loss: ", InpMaxDailyLossPct, "%");
    Print("  Max Total DD: ", InpMaxTotalDDPct, "%");
    Print("═══════════════════════════════════════════════════");
    Print("✅ POUTINE EA INITIALIZED SUCCESSFULLY");
    Print("═══════════════════════════════════════════════════");
}
//+------------------------------------------------------------------+
