//+------------------------------------------------------------------+
//|                                               Poutine_EURUSD.mq5 |
//|                    INSTITUTIONAL GRADE LONDON BREAKOUT EA        |
//|                   https://github.com/tradingluca31-boop/Poutine  |
//+------------------------------------------------------------------+
#property copyright "Poutine EA v3.0 - EURUSD Institutional"
#property link      "https://github.com/tradingluca31-boop/Poutine"
#property version   "3.00"
#property description "=== POUTINE EA v3.0 - EURUSD ==="
#property description "Institutional Grade London Breakout for EURUSD"
#property description "Based on ICT Smart Money Concepts + Volatility Breakout"
#property description "Inspired by FXStabilizer, GPS Robot, Forex Trend Detector"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| ENUMS                                                             |
//+------------------------------------------------------------------+
enum ENUM_SL_TYPE
{
    SL_ASIAN_MID,         // Middle of Asian Range
    SL_ASIAN_OPPOSITE,    // Opposite Side of Range
    SL_ATR_BASED,         // ATR-Based Dynamic
    SL_FIXED_PIPS         // Fixed Pips
};

enum ENUM_ENTRY_TYPE
{
    ENTRY_CANDLE_CLOSE,   // Wait for Candle Close (Safe)
    ENTRY_IMMEDIATE,      // Immediate on Breakout (Aggressive)
    ENTRY_RETEST          // Wait for Retest (Conservative)
};

enum ENUM_MARKET_BIAS
{
    BIAS_AUTO,            // Auto-detect with Higher TF
    BIAS_LONG_ONLY,       // Long Only
    BIAS_SHORT_ONLY,      // Short Only
    BIAS_BOTH             // Both Directions
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "══════════ RISK MANAGEMENT ══════════"
input double   InpRiskPercent       = 1.0;              // Risk % Per Trade
input double   InpRiskReward        = 2.0;              // Risk:Reward Ratio (2R optimal for EURUSD)
input double   InpMaxDailyLossPct   = 4.0;              // Max Daily Loss % (FTMO: 5%)
input double   InpMaxTotalDDPct     = 8.0;              // Max Total Drawdown % (FTMO: 10%)
input bool     InpUseFTMOProtection = true;             // Enable FTMO Protection

input group "══════════ TRADE SETTINGS ══════════"
input int      InpMagicNumber       = 202402;           // Magic Number
input ENUM_SL_TYPE InpSLType        = SL_ATR_BASED;     // Stop Loss Type
input ENUM_ENTRY_TYPE InpEntryType  = ENTRY_CANDLE_CLOSE; // Entry Type
input ENUM_MARKET_BIAS InpMarketBias = BIAS_AUTO;       // Market Bias Filter
input double   InpFixedSLPips       = 15.0;             // Fixed SL in Pips (if SL_FIXED_PIPS)
input bool     InpUseTrailingStop   = true;             // Use Trailing Stop
input double   InpTrailingATRMult   = 1.5;              // Trailing Stop ATR Multiplier

input group "══════════ SESSION TIMES (GMT) ══════════"
input int      InpAsianStartHour    = 0;                // Asian Range Start (GMT)
input int      InpAsianEndHour      = 7;                // Asian Range End (GMT) - Full Asian session
input int      InpLondonStartHour   = 8;                // London Entry Start (GMT) - London open
input int      InpLondonEndHour     = 11;               // London Entry End (GMT)
input int      InpOverlapStartHour  = 13;               // London-NY Overlap Start (BEST TIME!)
input int      InpOverlapEndHour    = 17;               // London-NY Overlap End (GMT)
input int      InpForceCloseHour    = 21;               // Force Close Hour (GMT)
input int      InpBrokerGMTOffset   = 2;                // Broker GMT Offset (for backtest)
input bool     InpTradeOverlap      = true;             // Trade London-NY Overlap (Recommended)

input group "══════════ BREAKOUT FILTERS ══════════"
input ENUM_TIMEFRAMES InpConfirmTF  = PERIOD_M15;       // Confirmation Timeframe
input int      InpMinRangePips      = 5;                // Min Asian Range (pips) - Reduced for more trades
input int      InpMaxRangePips      = 100;              // Max Asian Range (pips) - Increased
input int      InpBreakoutBuffer    = 2;                // Breakout Buffer (pips)
input int      InpMaxSpreadPips     = 5;                // Max Spread (pips) - Increased for backtest

input group "══════════ INDICATOR FILTERS ══════════"
input bool     InpUseRSIFilter      = true;             // Use RSI Confirmation
input int      InpRSIPeriod         = 14;               // RSI Period
input int      InpRSILongLevel      = 50;               // RSI Level for Long (>)
input int      InpRSIShortLevel     = 50;               // RSI Level for Short (<)
input bool     InpUseEMAFilter      = true;             // Use EMA Trend Filter
input int      InpEMAFastPeriod     = 5;                // Fast EMA Period
input int      InpEMASlowPeriod     = 12;               // Slow EMA Period
input bool     InpUseATRFilter      = false;            // Use ATR Volatility Filter (OFF by default)
input int      InpATRPeriod         = 14;               // ATR Period
input double   InpMinATRPips        = 3.0;              // Min ATR (pips)

input group "══════════ SMART MONEY FILTERS ══════════"
input bool     InpUseLiquiditySweep = false;            // Detect Liquidity Sweeps (OFF for simplicity)
input int      InpSweepBufferPips   = 5;                // Sweep Detection Buffer (pips)
input bool     InpUseHigherTFFilter = true;             // Use Higher TF Trend Filter
input ENUM_TIMEFRAMES InpHigherTF   = PERIOD_H4;        // Higher Timeframe for Bias

input group "══════════ INSTITUTIONAL FILTERS ══════════"
input bool     InpAvoidMonday       = false;            // Avoid Monday (low liquidity)
input bool     InpAvoidFriday       = false;            // Avoid Friday afternoon
input int      InpFridayCloseHour   = 18;               // Friday Close Hour (GMT)
input bool     InpAvoidRollover     = false;            // Avoid Rollover Time (21:00-01:00)

input group "══════════ DISPLAY ══════════"
input bool     InpShowPanel         = true;             // Show Info Panel
input bool     InpDrawBoxes         = true;             // Draw Asian Range Box
input color    InpBoxColorBull      = clrDodgerBlue;    // Bullish Breakout Color
input color    InpBoxColorBear      = clrOrangeRed;     // Bearish Breakout Color
input color    InpBoxColorNeutral   = clrDimGray;       // Neutral Box Color

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
CTrade         trade;
CPositionInfo  posInfo;
CAccountInfo   accInfo;

// Pip value for EURUSD
double         g_PipValue;
int            g_PipDigits;

// Session data
double         g_AsianHigh = 0;
double         g_AsianLow = 0;
double         g_AsianMid = 0;
double         g_AsianRangePips = 0;
bool           g_RangeCalculated = false;

// Trade management
bool           g_TradeTakenToday = false;
int            g_TradesToday = 0;
datetime       g_LastTradeDate = 0;
int            g_BrokerGMTOffset = 0;
double         g_DailyStartBalance = 0;
double         g_InitialBalance = 0;

// Smart Money tracking
bool           g_LiquiditySweepDetected = false;
int            g_SweepDirection = 0;
int            g_MarketBias = 0;  // 1 = bullish, -1 = bearish, 0 = neutral

// Indicator handles
int            g_ATRHandle = INVALID_HANDLE;
int            g_ATRHandleHTF = INVALID_HANDLE;
int            g_RSIHandle = INVALID_HANDLE;
int            g_EMAFastHandle = INVALID_HANDLE;
int            g_EMASlowHandle = INVALID_HANDLE;

// EMA handles for higher TF trend detection
int            g_EMA50Handle = INVALID_HANDLE;
int            g_EMA200Handle = INVALID_HANDLE;

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
    // Calculate pip value
    g_PipDigits = (_Digits == 5 || _Digits == 3) ? 1 : 0;
    g_PipValue = _Point * MathPow(10, g_PipDigits);

    // Validate symbol
    string symbol = Symbol();
    if(StringFind(symbol, "EUR") < 0 && StringFind(symbol, "USD") < 0)
    {
        Print("WARNING: Poutine EURUSD EA is optimized for EUR/USD pairs!");
        Print("Current symbol: ", symbol);
    }

    // Initialize trade object
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_IOC);

    // Initialize ATR handles
    g_ATRHandle = iATR(Symbol(), InpConfirmTF, InpATRPeriod);
    g_ATRHandleHTF = iATR(Symbol(), InpHigherTF, InpATRPeriod);

    if(g_ATRHandle == INVALID_HANDLE || g_ATRHandleHTF == INVALID_HANDLE)
    {
        Print("Failed to create ATR indicators");
        return(INIT_FAILED);
    }

    // Initialize RSI handle
    if(InpUseRSIFilter)
    {
        g_RSIHandle = iRSI(Symbol(), InpConfirmTF, InpRSIPeriod, PRICE_CLOSE);
        if(g_RSIHandle == INVALID_HANDLE)
        {
            Print("Failed to create RSI indicator");
            return(INIT_FAILED);
        }
    }

    // Initialize EMA handles for entry filter
    if(InpUseEMAFilter)
    {
        g_EMAFastHandle = iMA(Symbol(), InpConfirmTF, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
        g_EMASlowHandle = iMA(Symbol(), InpConfirmTF, InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);

        if(g_EMAFastHandle == INVALID_HANDLE || g_EMASlowHandle == INVALID_HANDLE)
        {
            Print("Failed to create EMA entry indicators");
            return(INIT_FAILED);
        }
    }

    // Initialize EMA handles for higher TF trend detection
    if(InpUseHigherTFFilter)
    {
        g_EMA50Handle = iMA(Symbol(), InpHigherTF, 50, 0, MODE_EMA, PRICE_CLOSE);
        g_EMA200Handle = iMA(Symbol(), InpHigherTF, 200, 0, MODE_EMA, PRICE_CLOSE);

        if(g_EMA50Handle == INVALID_HANDLE || g_EMA200Handle == INVALID_HANDLE)
        {
            Print("Failed to create EMA indicators");
            return(INIT_FAILED);
        }
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
    // Release indicator handles
    if(g_ATRHandle != INVALID_HANDLE) IndicatorRelease(g_ATRHandle);
    if(g_ATRHandleHTF != INVALID_HANDLE) IndicatorRelease(g_ATRHandleHTF);
    if(g_EMA50Handle != INVALID_HANDLE) IndicatorRelease(g_EMA50Handle);
    if(g_EMA200Handle != INVALID_HANDLE) IndicatorRelease(g_EMA200Handle);
    if(g_RSIHandle != INVALID_HANDLE) IndicatorRelease(g_RSIHandle);
    if(g_EMAFastHandle != INVALID_HANDLE) IndicatorRelease(g_EMAFastHandle);
    if(g_EMASlowHandle != INVALID_HANDLE) IndicatorRelease(g_EMASlowHandle);

    // Clean up chart objects
    ObjectsDeleteAll(0, "Poutine_");
    Comment("");

    Print("═══════════════════════════════════════");
    Print("POUTINE EURUSD EA STOPPED");
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

    // Get day of week
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int dayOfWeek = dt.day_of_week;

    // Check for new day and reset
    CheckNewDay();

    // Institutional filters
    if(!PassInstitutionalFilters(gmtHour, dayOfWeek))
    {
        if(InpShowPanel) UpdatePanel("INSTITUTIONAL FILTER ACTIVE");
        return;
    }

    // FTMO Protection Check
    if(InpUseFTMOProtection && !CheckFTMOLimits())
    {
        if(InpShowPanel) UpdatePanel("FTMO LIMIT REACHED");
        return;
    }

    // Update market bias from higher timeframe
    if(InpUseHigherTFFilter || InpMarketBias == BIAS_AUTO)
    {
        UpdateMarketBias();
    }

    // Phase 1: Calculate Asian Range (00:00 - 06:00 GMT for EURUSD)
    if(gmtHour >= InpAsianStartHour && gmtHour < InpAsianEndHour)
    {
        CalculateAsianRange();
        if(InpShowPanel) UpdatePanel("CALCULATING ASIAN RANGE...");
    }

    // Phase 2: London Breakout Entry (07:00 - 11:00 GMT)
    if(gmtHour >= InpLondonStartHour && gmtHour < InpLondonEndHour)
    {
        // Finalize Asian range at London open
        if(!g_RangeCalculated && g_AsianHigh > 0 && g_AsianLow > 0)
        {
            FinalizeAsianRange();
        }

        if(g_RangeCalculated && !g_TradeTakenToday && !HasOpenPosition())
        {
            if(InpShowPanel) UpdatePanel("LONDON SESSION - SCANNING...");

            // Smart Money: Check for liquidity sweep
            if(InpUseLiquiditySweep)
            {
                DetectLiquiditySweep();
            }

            CheckForBreakout("LONDON");
        }
    }

    // Phase 3: London-NY Overlap Entry (13:00 - 17:00 GMT) - BEST TIME FOR EURUSD!
    if(InpTradeOverlap && gmtHour >= InpOverlapStartHour && gmtHour < InpOverlapEndHour)
    {
        if(g_RangeCalculated && g_TradesToday < 2 && !HasOpenPosition())
        {
            if(InpShowPanel) UpdatePanel("OVERLAP SESSION - SCANNING...");
            CheckForBreakout("OVERLAP");
        }
    }

    // Phase 4: Trade Management
    if(HasOpenPosition())
    {
        ManagePosition();
        if(InpShowPanel) UpdatePanel("POSITION ACTIVE - MANAGING...");
    }

    // Phase 5: Force Close (21:00 GMT)
    if(gmtHour >= InpForceCloseHour)
    {
        ForceCloseAllPositions("End of Day");
        if(InpShowPanel) UpdatePanel("SESSION ENDED");
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

                        Print("=== TRADE CLOSED ===");
                        Print("Profit: $", DoubleToString(profit, 2));
                        Print("Win Rate: ", DoubleToString((double)g_WinTrades / g_TotalTrades * 100, 1), "%");
                    }
                }
            }
        }
    }
    lastHistoryTotal = currentHistoryTotal;
}

//+------------------------------------------------------------------+
//| Pass Institutional Filters                                        |
//+------------------------------------------------------------------+
bool PassInstitutionalFilters(int gmtHour, int dayOfWeek)
{
    // Avoid Monday
    if(InpAvoidMonday && dayOfWeek == 1 && gmtHour < 8)
        return false;

    // Avoid Friday afternoon
    if(InpAvoidFriday && dayOfWeek == 5 && gmtHour >= InpFridayCloseHour)
        return false;

    // Avoid rollover time
    if(InpAvoidRollover && (gmtHour >= 21 || gmtHour < 1))
        return false;

    return true;
}

//+------------------------------------------------------------------+
//| Update Market Bias from Higher Timeframe                          |
//+------------------------------------------------------------------+
void UpdateMarketBias()
{
    if(InpMarketBias == BIAS_LONG_ONLY)
    {
        g_MarketBias = 1;
        return;
    }
    if(InpMarketBias == BIAS_SHORT_ONLY)
    {
        g_MarketBias = -1;
        return;
    }
    if(InpMarketBias == BIAS_BOTH)
    {
        g_MarketBias = 0;
        return;
    }

    // Auto-detect using EMA 50/200 on higher timeframe
    if(g_EMA50Handle == INVALID_HANDLE || g_EMA200Handle == INVALID_HANDLE)
    {
        g_MarketBias = 0;
        return;
    }

    double ema50[], ema200[];
    ArraySetAsSeries(ema50, true);
    ArraySetAsSeries(ema200, true);

    if(CopyBuffer(g_EMA50Handle, 0, 0, 2, ema50) <= 0) return;
    if(CopyBuffer(g_EMA200Handle, 0, 0, 2, ema200) <= 0) return;

    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);

    // Bullish: Price > EMA50 > EMA200
    if(currentPrice > ema50[0] && ema50[0] > ema200[0])
    {
        g_MarketBias = 1;
    }
    // Bearish: Price < EMA50 < EMA200
    else if(currentPrice < ema50[0] && ema50[0] < ema200[0])
    {
        g_MarketBias = -1;
    }
    else
    {
        g_MarketBias = 0;  // Neutral/ranging
    }
}

//+------------------------------------------------------------------+
//| Calculate Asian Session Range                                     |
//+------------------------------------------------------------------+
void CalculateAsianRange()
{
    if(g_RangeCalculated) return;

    datetime currentTime = TimeCurrent();
    datetime todayStart = StringToTime(TimeToString(currentTime, TIME_DATE));
    datetime asianStart = todayStart + (InpAsianStartHour + g_BrokerGMTOffset) * 3600;

    if(InpAsianStartHour + g_BrokerGMTOffset >= 24)
        asianStart -= 86400;
    if(InpAsianStartHour + g_BrokerGMTOffset < 0)
        asianStart += 86400;

    double high = 0;
    double low = DBL_MAX;
    int barsFound = 0;

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
        g_AsianRangePips = (high - low) / g_PipValue;

        Print("=== ASIAN RANGE ===");
        Print("High: ", DoubleToString(g_AsianHigh, _Digits));
        Print("Low: ", DoubleToString(g_AsianLow, _Digits));
        Print("Range: ", DoubleToString(g_AsianRangePips, 1), " pips");
    }
}

//+------------------------------------------------------------------+
//| Finalize Asian Range                                              |
//+------------------------------------------------------------------+
void FinalizeAsianRange()
{
    if(g_AsianHigh > 0 && g_AsianLow > 0 && !g_RangeCalculated)
    {
        g_AsianRangePips = (g_AsianHigh - g_AsianLow) / g_PipValue;
        g_RangeCalculated = true;
        Print("Asian Range Finalized: ", DoubleToString(g_AsianRangePips, 1), " pips");
    }
}

//+------------------------------------------------------------------+
//| Detect Institutional Liquidity Sweep                              |
//+------------------------------------------------------------------+
void DetectLiquiditySweep()
{
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double sweepBuffer = InpSweepBufferPips * g_PipValue;

    // Bullish sweep: Price swept below Asian Low then reversed
    double recentLow = iLow(Symbol(), InpConfirmTF, 1);
    if(recentLow < g_AsianLow - sweepBuffer && currentPrice > g_AsianLow)
    {
        g_LiquiditySweepDetected = true;
        g_SweepDirection = 1;  // Bullish
        Print("LIQUIDITY SWEEP: Bullish (swept lows)");
    }

    // Bearish sweep: Price swept above Asian High then reversed
    double recentHigh = iHigh(Symbol(), InpConfirmTF, 1);
    if(recentHigh > g_AsianHigh + sweepBuffer && currentPrice < g_AsianHigh)
    {
        g_LiquiditySweepDetected = true;
        g_SweepDirection = -1;  // Bearish
        Print("LIQUIDITY SWEEP: Bearish (swept highs)");
    }
}

//+------------------------------------------------------------------+
//| Check for Breakout Entry                                          |
//+------------------------------------------------------------------+
void CheckForBreakout(string session)
{
    if(!g_RangeCalculated) return;

    // Validate range size
    if(g_AsianRangePips < InpMinRangePips)
    {
        return;
    }

    if(g_AsianRangePips > InpMaxRangePips)
    {
        return;
    }

    // Check spread
    double spreadPips = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * _Point / g_PipValue;
    if(spreadPips > InpMaxSpreadPips)
    {
        return;
    }

    // ATR Filter
    if(InpUseATRFilter)
    {
        double atrPips = GetATR() / g_PipValue;
        if(atrPips < InpMinATRPips)
        {
            return;
        }
    }

    // Pre-trade margin check
    if(!CheckMarginForTrade())
    {
        Print("Insufficient margin");
        return;
    }

    double buffer = InpBreakoutBuffer * g_PipValue;
    bool buySignal = false;
    bool sellSignal = false;

    if(InpEntryType == ENTRY_CANDLE_CLOSE)
    {
        double close1 = iClose(Symbol(), InpConfirmTF, 1);
        double open1 = iOpen(Symbol(), InpConfirmTF, 1);

        // Bullish breakout
        if(close1 > g_AsianHigh + buffer && close1 > open1)
        {
            buySignal = true;
        }
        // Bearish breakout
        else if(close1 < g_AsianLow - buffer && close1 < open1)
        {
            sellSignal = true;
        }
    }
    else if(InpEntryType == ENTRY_IMMEDIATE)
    {
        double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

        if(ask > g_AsianHigh + buffer)
            buySignal = true;
        else if(bid < g_AsianLow - buffer)
            sellSignal = true;
    }

    // Market bias filter
    if(InpMarketBias == BIAS_AUTO && g_MarketBias != 0)
    {
        if(g_MarketBias == -1 && buySignal)
        {
            Print("BUY filtered by bearish market bias");
            buySignal = false;
        }
        else if(g_MarketBias == 1 && sellSignal)
        {
            Print("SELL filtered by bullish market bias");
            sellSignal = false;
        }
    }

    // Smart Money confirmation
    if(InpUseLiquiditySweep && g_LiquiditySweepDetected)
    {
        if(g_SweepDirection == 1 && sellSignal)
        {
            sellSignal = false;
        }
        else if(g_SweepDirection == -1 && buySignal)
        {
            buySignal = false;
        }
    }

    // RSI Filter - Confirm momentum direction
    if(InpUseRSIFilter && g_RSIHandle != INVALID_HANDLE)
    {
        double rsi[];
        ArraySetAsSeries(rsi, true);

        if(CopyBuffer(g_RSIHandle, 0, 0, 2, rsi) > 0)
        {
            // For BUY: RSI must be > 50 (bullish momentum)
            if(buySignal && rsi[0] <= InpRSILongLevel)
            {
                Print("BUY filtered: RSI ", DoubleToString(rsi[0], 1), " <= ", InpRSILongLevel);
                buySignal = false;
            }
            // For SELL: RSI must be < 50 (bearish momentum)
            if(sellSignal && rsi[0] >= InpRSIShortLevel)
            {
                Print("SELL filtered: RSI ", DoubleToString(rsi[0], 1), " >= ", InpRSIShortLevel);
                sellSignal = false;
            }
        }
    }

    // EMA 5/12 Crossover Filter - Confirm trend alignment
    if(InpUseEMAFilter && g_EMAFastHandle != INVALID_HANDLE && g_EMASlowHandle != INVALID_HANDLE)
    {
        double emaFast[], emaSlow[];
        ArraySetAsSeries(emaFast, true);
        ArraySetAsSeries(emaSlow, true);

        if(CopyBuffer(g_EMAFastHandle, 0, 0, 2, emaFast) > 0 &&
           CopyBuffer(g_EMASlowHandle, 0, 0, 2, emaSlow) > 0)
        {
            // For BUY: Fast EMA must be above Slow EMA (bullish trend)
            if(buySignal && emaFast[0] <= emaSlow[0])
            {
                Print("BUY filtered: EMA", InpEMAFastPeriod, " <= EMA", InpEMASlowPeriod);
                buySignal = false;
            }
            // For SELL: Fast EMA must be below Slow EMA (bearish trend)
            if(sellSignal && emaFast[0] >= emaSlow[0])
            {
                Print("SELL filtered: EMA", InpEMAFastPeriod, " >= EMA", InpEMASlowPeriod);
                sellSignal = false;
            }
        }
    }

    // Execute trade
    if(buySignal)
    {
        ExecuteTrade(ORDER_TYPE_BUY, session);
    }
    else if(sellSignal)
    {
        ExecuteTrade(ORDER_TYPE_SELL, session);
    }
}

//+------------------------------------------------------------------+
//| Execute Trade                                                     |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType, string session)
{
    double entryPrice = 0, slPrice = 0, tpPrice = 0, slDistance = 0;

    if(orderType == ORDER_TYPE_BUY)
    {
        entryPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

        switch(InpSLType)
        {
            case SL_ASIAN_MID:
                slPrice = g_AsianMid;
                break;
            case SL_ASIAN_OPPOSITE:
                slPrice = g_AsianLow - InpBreakoutBuffer * g_PipValue;
                break;
            case SL_ATR_BASED:
                slPrice = entryPrice - GetATR() * 1.5;
                break;
            case SL_FIXED_PIPS:
                slPrice = entryPrice - InpFixedSLPips * g_PipValue;
                break;
        }

        slDistance = entryPrice - slPrice;
        tpPrice = entryPrice + (slDistance * InpRiskReward);
    }
    else
    {
        entryPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);

        switch(InpSLType)
        {
            case SL_ASIAN_MID:
                slPrice = g_AsianMid;
                break;
            case SL_ASIAN_OPPOSITE:
                slPrice = g_AsianHigh + InpBreakoutBuffer * g_PipValue;
                break;
            case SL_ATR_BASED:
                slPrice = entryPrice + GetATR() * 1.5;
                break;
            case SL_FIXED_PIPS:
                slPrice = entryPrice + InpFixedSLPips * g_PipValue;
                break;
        }

        slDistance = slPrice - entryPrice;
        tpPrice = entryPrice - (slDistance * InpRiskReward);
    }

    double lotSize = CalculateLotSize(slDistance);

    if(lotSize <= 0)
    {
        Print("Invalid lot size");
        return;
    }

    slPrice = NormalizeDouble(slPrice, _Digits);
    tpPrice = NormalizeDouble(tpPrice, _Digits);
    entryPrice = NormalizeDouble(entryPrice, _Digits);

    string comment = StringFormat("Poutine_%s_%s_R%.1f",
                                  session,
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
        g_TradesToday++;

        Print("═══════════════════════════════════════");
        Print(orderType == ORDER_TYPE_BUY ? "BUY" : "SELL", " ORDER - ", session, " SESSION");
        Print("Entry: ", DoubleToString(entryPrice, _Digits));
        Print("SL: ", DoubleToString(slPrice, _Digits), " (", DoubleToString(slDistance / g_PipValue, 1), " pips)");
        Print("TP: ", DoubleToString(tpPrice, _Digits), " (R:", InpRiskReward, ")");
        Print("Lot: ", DoubleToString(lotSize, 2), " | Risk: ", InpRiskPercent, "%");
        Print("Market Bias: ", g_MarketBias == 1 ? "BULLISH" : g_MarketBias == -1 ? "BEARISH" : "NEUTRAL");
        Print("═══════════════════════════════════════");
    }
    else
    {
        Print("Order failed: ", GetLastError(), " - ", trade.ResultComment());
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
            double potentialSL = bid - trailDistance;
            if(potentialSL > openPrice && potentialSL > currentSL)
            {
                newSL = NormalizeDouble(potentialSL, _Digits);
            }
        }
        else
        {
            double potentialSL = ask + trailDistance;
            if(potentialSL < openPrice && (currentSL == 0 || potentialSL < currentSL))
            {
                newSL = NormalizeDouble(potentialSL, _Digits);
            }
        }

        if(newSL > 0 && newSL != currentSL)
        {
            if(trade.PositionModify(ticket, newSL, currentTP))
            {
                Print("Trailing Stop: ", DoubleToString(newSL, _Digits));
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
            Print("Position closed: ", reason);
        }
    }
}

//+------------------------------------------------------------------+
//| Check FTMO Limits                                                 |
//+------------------------------------------------------------------+
bool CheckFTMOLimits()
{
    double currentEquity = accInfo.Equity();

    double dailyLoss = g_DailyStartBalance - currentEquity;
    double dailyLossPct = (dailyLoss / g_DailyStartBalance) * 100;

    if(dailyLossPct >= InpMaxDailyLossPct)
    {
        ForceCloseAllPositions("FTMO Daily Limit");
        return false;
    }

    double totalDD = g_InitialBalance - currentEquity;
    double totalDDPct = (totalDD / g_InitialBalance) * 100;

    if(totalDDPct >= InpMaxTotalDDPct)
    {
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
        g_LastTradeDate = today;
        g_DailyStartBalance = accInfo.Balance();
        ResetDailyVariables();

        Print("═══════════════════════════════════════");
        Print("NEW TRADING DAY");
        Print("Balance: $", DoubleToString(g_DailyStartBalance, 2));
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
    g_AsianRangePips = 0;
    g_RangeCalculated = false;
    g_TradeTakenToday = false;
    g_TradesToday = 0;
    g_LiquiditySweepDetected = false;
    g_SweepDirection = 0;

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
    if(MQLInfoInteger(MQL_TESTER))
    {
        return InpBrokerGMTOffset;
    }

    datetime brokerTime = TimeCurrent();
    datetime gmtTime = TimeGMT();

    if(gmtTime == 0) return InpBrokerGMTOffset;

    int offset = (int)((brokerTime - gmtTime) / 3600);

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

    string highName = "Poutine_High";
    string lowName = "Poutine_Low";
    string midName = "Poutine_Mid";

    ObjectDelete(0, highName);
    ObjectCreate(0, highName, OBJ_HLINE, 0, 0, g_AsianHigh);
    ObjectSetInteger(0, highName, OBJPROP_COLOR, InpBoxColorBull);
    ObjectSetInteger(0, highName, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(0, highName, OBJPROP_WIDTH, 2);

    ObjectDelete(0, lowName);
    ObjectCreate(0, lowName, OBJ_HLINE, 0, 0, g_AsianLow);
    ObjectSetInteger(0, lowName, OBJPROP_COLOR, InpBoxColorBear);
    ObjectSetInteger(0, lowName, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(0, lowName, OBJPROP_WIDTH, 2);

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

    string biasStr = g_MarketBias == 1 ? "BULLISH" : g_MarketBias == -1 ? "BEARISH" : "NEUTRAL";

    string info = "\n";
    info += "========================================\n";
    info += "   POUTINE EA v3.0 - EURUSD\n";
    info += "   Institutional London Breakout\n";
    info += "========================================\n";
    info += " Status: " + status + "\n";
    info += " GMT: " + IntegerToString(gmtHour) + ":" + (gmtMinute < 10 ? "0" : "") + IntegerToString(gmtMinute) + "\n";
    info += "----------------------------------------\n";
    info += " ASIAN RANGE:\n";
    info += "   High: " + DoubleToString(g_AsianHigh, _Digits) + "\n";
    info += "   Low:  " + DoubleToString(g_AsianLow, _Digits) + "\n";
    info += "   Size: " + DoubleToString(g_AsianRangePips, 1) + " pips\n";
    info += "----------------------------------------\n";
    info += " MARKET BIAS: " + biasStr + "\n";
    info += "----------------------------------------\n";
    info += " Equity: $" + DoubleToString(equity, 2) + "\n";
    info += " Daily P/L: " + (dailyPL >= 0 ? "+" : "") + DoubleToString(dailyPL, 2) + "\n";
    info += "----------------------------------------\n";
    info += " Trades: " + IntegerToString(g_TotalTrades) + " | WR: " +
            (g_TotalTrades > 0 ? DoubleToString((double)g_WinTrades / g_TotalTrades * 100, 1) : "0") + "%\n";
    info += "========================================\n";

    Comment(info);
}

//+------------------------------------------------------------------+
//| Print Initialization Info                                         |
//+------------------------------------------------------------------+
void PrintInitInfo()
{
    Print("═══════════════════════════════════════════════════");
    Print("     POUTINE EA v3.0 - EURUSD INSTITUTIONAL");
    Print("        London Breakout | Smart Money");
    Print("═══════════════════════════════════════════════════");
    Print("Symbol: ", Symbol());
    Print("Pip Value: ", DoubleToString(g_PipValue, _Digits));
    Print("Risk: ", InpRiskPercent, "% | R:R = 1:", InpRiskReward);
    Print("Magic: ", InpMagicNumber);
    Print("GMT Offset: ", g_BrokerGMTOffset, "h");
    Print("═══════════════════════════════════════════════════");
    Print("SESSIONS (GMT):");
    Print("  Asian: ", InpAsianStartHour, ":00 - ", InpAsianEndHour, ":00");
    Print("  London: ", InpLondonStartHour, ":00 - ", InpLondonEndHour, ":00");
    Print("  Overlap: ", InpOverlapStartHour, ":00 - ", InpOverlapEndHour, ":00");
    Print("═══════════════════════════════════════════════════");
    Print("FILTERS:");
    Print("  Range: ", InpMinRangePips, " - ", InpMaxRangePips, " pips");
    Print("  Max Spread: ", InpMaxSpreadPips, " pips");
    Print("  Higher TF Filter: ", InpUseHigherTFFilter ? "ON" : "OFF");
    Print("  Smart Money: ", InpUseLiquiditySweep ? "ON" : "OFF");
    Print("═══════════════════════════════════════════════════");
    Print("INSTITUTIONAL FILTERS:");
    Print("  Avoid Monday: ", InpAvoidMonday ? "ON" : "OFF");
    Print("  Avoid Friday PM: ", InpAvoidFriday ? "ON" : "OFF");
    Print("  Avoid Rollover: ", InpAvoidRollover ? "ON" : "OFF");
    Print("═══════════════════════════════════════════════════");
    Print("POUTINE EURUSD EA INITIALIZED");
    Print("═══════════════════════════════════════════════════");
}
//+------------------------------------------------------------------+
