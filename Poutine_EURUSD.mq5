//+------------------------------------------------------------------+
//|                                               Poutine_EURUSD.mq5 |
//|                    INSTITUTIONAL GRADE TREND FOLLOWING EA        |
//|                   https://github.com/tradingluca31-boop/Poutine  |
//+------------------------------------------------------------------+
#property copyright "Poutine EA v4.0 - EURUSD Trend Following"
#property link      "https://github.com/tradingluca31-boop/Poutine"
#property version   "4.10"
#property description "=== POUTINE EA v4.0 - EURUSD TREND FOLLOWING ==="
#property description "Institutional Grade Trend Following Strategy"
#property description "ADX + EMA + MACD + RSI Multi-Filter System"
#property description "Optimized for EURUSD M15/H1"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| ENUMS                                                             |
//+------------------------------------------------------------------+
enum ENUM_ENTRY_MODE
{
    ENTRY_CONSERVATIVE,   // Conservative (all filters must align)
    ENTRY_MODERATE,       // Moderate (ADX + EMA + one other)
    ENTRY_AGGRESSIVE      // Aggressive (ADX + EMA only)
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "══════════ RISK MANAGEMENT ══════════"
input double   InpRiskPercent       = 1.0;              // Risk % Per Trade
input double   InpRiskReward        = 2.0;              // Risk:Reward Ratio (2R - more realistic)
input double   InpMaxDailyLossPct   = 4.0;              // Max Daily Loss % (FTMO: 5%)
input double   InpMaxTotalDDPct     = 100.0;            // Max Total Drawdown % (disabled for backtest)
input bool     InpUseFTMOProtection = false;            // Enable FTMO Protection (OFF for backtest)

input group "══════════ TRADE SETTINGS ══════════"
input int      InpMagicNumber       = 202403;           // Magic Number
input ENUM_ENTRY_MODE InpEntryMode  = ENTRY_CONSERVATIVE; // Entry Mode (Quality vs Quantity)
input int      InpMaxTradesPerDay   = 2;                // Max Trades Per Day
input bool     InpUseTrailingStop   = false;            // Use Trailing Stop (OFF = let TP hit)
input double   InpTrailingATRMult   = 2.0;              // Trailing Stop ATR Multiplier

input group "══════════ TIMEFRAMES ══════════"
input ENUM_TIMEFRAMES InpEntryTF    = PERIOD_M15;       // Entry Timeframe
input ENUM_TIMEFRAMES InpTrendTF    = PERIOD_H1;        // Trend Confirmation TF
input ENUM_TIMEFRAMES InpBiasTF     = PERIOD_H4;        // Higher TF Bias

input group "══════════ SESSION TIMES (GMT) ══════════"
input int      InpSessionStartHour  = 7;                // Session Start (GMT) - London Open
input int      InpSessionEndHour    = 20;               // Session End (GMT) - Before Asia
input int      InpBrokerGMTOffset   = 2;                // Broker GMT Offset (for backtest)
input bool     InpAvoidNews         = false;            // Avoid Major News (manual check)

input group "══════════ ADX FILTER (Trend Strength) ══════════"
input bool     InpUseADX            = true;             // Use ADX Filter
input int      InpADXPeriod         = 14;               // ADX Period
input int      InpADXMinLevel       = 25;               // Min ADX for Strong Trend
input int      InpADXMaxLevel       = 50;               // Max ADX (avoid exhaustion)

input group "══════════ EMA TREND FILTER ══════════"
input bool     InpUseEMAFilter      = true;             // Use EMA Trend Filter
input int      InpEMAFast           = 20;               // Fast EMA Period
input int      InpEMAMedium         = 50;               // Medium EMA Period
input int      InpEMASlow           = 200;              // Slow EMA Period

input group "══════════ MACD FILTER ══════════"
input bool     InpUseMACD           = true;             // Use MACD Confirmation
input int      InpMACDFast          = 12;               // MACD Fast EMA
input int      InpMACDSlow          = 26;               // MACD Slow EMA
input int      InpMACDSignal        = 9;                // MACD Signal Period

input group "══════════ RSI FILTER ══════════"
input bool     InpUseRSI            = true;             // Use RSI Filter
input int      InpRSIPeriod         = 14;               // RSI Period
input int      InpRSIOverbought     = 70;               // RSI Overbought (no buy above)
input int      InpRSIOversold       = 30;               // RSI Oversold (no sell below)

input group "══════════ ATR SETTINGS ══════════"
input int      InpATRPeriod         = 14;               // ATR Period
input double   InpSLMultiplier      = 1.5;              // SL = ATR x Multiplier (tighter)
input double   InpMinSLPips         = 10;               // Minimum SL in Pips
input double   InpMaxSLPips         = 25;               // Maximum SL in Pips (tighter TP)

input group "══════════ BREAK-EVEN ══════════"
input bool     InpUseBreakEven      = false;            // Move SL to entry at +1R (OFF for now)
input double   InpBreakEvenTrigger  = 1.0;              // Trigger BE at X times risk

input group "══════════ SPREAD FILTER ══════════"
input int      InpMaxSpreadPips     = 3;                // Max Spread (pips)

input group "══════════ DISPLAY ══════════"
input bool     InpShowPanel         = true;             // Show Info Panel

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
CTrade         trade;
CPositionInfo  posInfo;
CAccountInfo   accInfo;

// Pip value
double         g_PipValue;
int            g_PipDigits;

// Indicator handles - Entry TF
int            g_ADXHandle = INVALID_HANDLE;
int            g_EMAFastHandle = INVALID_HANDLE;
int            g_EMAMediumHandle = INVALID_HANDLE;
int            g_EMASlowHandle = INVALID_HANDLE;
int            g_MACDHandle = INVALID_HANDLE;
int            g_RSIHandle = INVALID_HANDLE;
int            g_ATRHandle = INVALID_HANDLE;

// Indicator handles - Trend TF (H1)
int            g_EMAFastH1 = INVALID_HANDLE;
int            g_EMASlowH1 = INVALID_HANDLE;
int            g_ADXH1 = INVALID_HANDLE;

// Indicator handles - Bias TF (H4)
int            g_EMAFastH4 = INVALID_HANDLE;
int            g_EMASlowH4 = INVALID_HANDLE;

// Trade management
int            g_TradesToday = 0;
datetime       g_LastTradeDate = 0;
int            g_BrokerGMTOffset = 0;
double         g_DailyStartBalance = 0;
double         g_InitialBalance = 0;

// Signal tracking
int            g_TrendDirection = 0;  // 1 = bullish, -1 = bearish, 0 = neutral
int            g_H1Trend = 0;
int            g_H4Bias = 0;

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
    // Calculate pip value for EURUSD (5 digits)
    g_PipDigits = (_Digits == 5 || _Digits == 3) ? 1 : 0;
    g_PipValue = _Point * MathPow(10, g_PipDigits);

    // Validate symbol
    string symbol = Symbol();
    if(StringFind(symbol, "EUR") < 0 || StringFind(symbol, "USD") < 0)
    {
        Print("WARNING: Poutine EA is optimized for EURUSD!");
        Print("Current symbol: ", symbol);
    }

    // Initialize trade object
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_IOC);

    // Initialize indicators on Entry TF
    if(!InitializeIndicators())
    {
        Print("Failed to initialize indicators");
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
//| Initialize all indicators                                         |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
    // ADX on Entry TF
    if(InpUseADX)
    {
        g_ADXHandle = iADX(Symbol(), InpEntryTF, InpADXPeriod);
        if(g_ADXHandle == INVALID_HANDLE) return false;

        g_ADXH1 = iADX(Symbol(), InpTrendTF, InpADXPeriod);
        if(g_ADXH1 == INVALID_HANDLE) return false;
    }

    // EMAs on Entry TF
    if(InpUseEMAFilter)
    {
        g_EMAFastHandle = iMA(Symbol(), InpEntryTF, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
        g_EMAMediumHandle = iMA(Symbol(), InpEntryTF, InpEMAMedium, 0, MODE_EMA, PRICE_CLOSE);
        g_EMASlowHandle = iMA(Symbol(), InpEntryTF, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);

        if(g_EMAFastHandle == INVALID_HANDLE || g_EMAMediumHandle == INVALID_HANDLE ||
           g_EMASlowHandle == INVALID_HANDLE) return false;

        // H1 EMAs for trend
        g_EMAFastH1 = iMA(Symbol(), InpTrendTF, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
        g_EMASlowH1 = iMA(Symbol(), InpTrendTF, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
        if(g_EMAFastH1 == INVALID_HANDLE || g_EMASlowH1 == INVALID_HANDLE) return false;

        // H4 EMAs for bias
        g_EMAFastH4 = iMA(Symbol(), InpBiasTF, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
        g_EMASlowH4 = iMA(Symbol(), InpBiasTF, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
        if(g_EMAFastH4 == INVALID_HANDLE || g_EMASlowH4 == INVALID_HANDLE) return false;
    }

    // MACD on Entry TF
    if(InpUseMACD)
    {
        g_MACDHandle = iMACD(Symbol(), InpEntryTF, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
        if(g_MACDHandle == INVALID_HANDLE) return false;
    }

    // RSI on Entry TF
    if(InpUseRSI)
    {
        g_RSIHandle = iRSI(Symbol(), InpEntryTF, InpRSIPeriod, PRICE_CLOSE);
        if(g_RSIHandle == INVALID_HANDLE) return false;
    }

    // ATR for SL/TP calculation
    g_ATRHandle = iATR(Symbol(), InpEntryTF, InpATRPeriod);
    if(g_ATRHandle == INVALID_HANDLE) return false;

    return true;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release all indicator handles
    if(g_ADXHandle != INVALID_HANDLE) IndicatorRelease(g_ADXHandle);
    if(g_ADXH1 != INVALID_HANDLE) IndicatorRelease(g_ADXH1);
    if(g_EMAFastHandle != INVALID_HANDLE) IndicatorRelease(g_EMAFastHandle);
    if(g_EMAMediumHandle != INVALID_HANDLE) IndicatorRelease(g_EMAMediumHandle);
    if(g_EMASlowHandle != INVALID_HANDLE) IndicatorRelease(g_EMASlowHandle);
    if(g_EMAFastH1 != INVALID_HANDLE) IndicatorRelease(g_EMAFastH1);
    if(g_EMASlowH1 != INVALID_HANDLE) IndicatorRelease(g_EMASlowH1);
    if(g_EMAFastH4 != INVALID_HANDLE) IndicatorRelease(g_EMAFastH4);
    if(g_EMASlowH4 != INVALID_HANDLE) IndicatorRelease(g_EMASlowH4);
    if(g_MACDHandle != INVALID_HANDLE) IndicatorRelease(g_MACDHandle);
    if(g_RSIHandle != INVALID_HANDLE) IndicatorRelease(g_RSIHandle);
    if(g_ATRHandle != INVALID_HANDLE) IndicatorRelease(g_ATRHandle);

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
    // Check for new day
    CheckNewDay();

    // Get GMT time
    int gmtHour, gmtMinute;
    GetGMTTime(gmtHour, gmtMinute);

    // Session filter
    if(gmtHour < InpSessionStartHour || gmtHour >= InpSessionEndHour)
    {
        if(InpShowPanel) UpdatePanel("OUTSIDE SESSION");
        return;
    }

    // FTMO Protection
    if(InpUseFTMOProtection && !CheckFTMOLimits())
    {
        if(InpShowPanel) UpdatePanel("FTMO LIMIT REACHED");
        return;
    }

    // Max trades per day
    if(g_TradesToday >= InpMaxTradesPerDay)
    {
        if(InpShowPanel) UpdatePanel("MAX TRADES REACHED");
        ManageOpenPositions();
        return;
    }

    // Spread filter
    double spreadPips = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * _Point / g_PipValue;
    if(spreadPips > InpMaxSpreadPips)
    {
        if(InpShowPanel) UpdatePanel("SPREAD TOO HIGH: " + DoubleToString(spreadPips, 1));
        ManageOpenPositions();
        return;
    }

    // Update trend analysis
    AnalyzeTrend();

    // Check for entry signals (only on new bar)
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(Symbol(), InpEntryTF, 0);

    if(currentBarTime != lastBarTime)
    {
        lastBarTime = currentBarTime;

        if(!HasOpenPosition())
        {
            CheckForEntry();
        }
    }

    // Manage open positions
    ManageOpenPositions();

    // Update panel
    if(InpShowPanel) UpdatePanel("SCANNING...");
}

//+------------------------------------------------------------------+
//| Analyze trend on multiple timeframes                              |
//+------------------------------------------------------------------+
void AnalyzeTrend()
{
    g_TrendDirection = 0;
    g_H1Trend = 0;
    g_H4Bias = 0;

    if(!InpUseEMAFilter) return;

    // Get H4 Bias (highest priority)
    double emaFastH4[], emaSlowH4[];
    ArraySetAsSeries(emaFastH4, true);
    ArraySetAsSeries(emaSlowH4, true);

    if(CopyBuffer(g_EMAFastH4, 0, 0, 2, emaFastH4) > 0 &&
       CopyBuffer(g_EMASlowH4, 0, 0, 2, emaSlowH4) > 0)
    {
        if(emaFastH4[0] > emaSlowH4[0]) g_H4Bias = 1;
        else if(emaFastH4[0] < emaSlowH4[0]) g_H4Bias = -1;
    }

    // Get H1 Trend
    double emaFastH1[], emaSlowH1[];
    ArraySetAsSeries(emaFastH1, true);
    ArraySetAsSeries(emaSlowH1, true);

    if(CopyBuffer(g_EMAFastH1, 0, 0, 2, emaFastH1) > 0 &&
       CopyBuffer(g_EMASlowH1, 0, 0, 2, emaSlowH1) > 0)
    {
        if(emaFastH1[0] > emaSlowH1[0]) g_H1Trend = 1;
        else if(emaFastH1[0] < emaSlowH1[0]) g_H1Trend = -1;
    }

    // Get Entry TF Trend (EMA 20 > 50 > 200 for bullish)
    double emaFast[], emaMedium[], emaSlow[];
    ArraySetAsSeries(emaFast, true);
    ArraySetAsSeries(emaMedium, true);
    ArraySetAsSeries(emaSlow, true);

    if(CopyBuffer(g_EMAFastHandle, 0, 0, 2, emaFast) > 0 &&
       CopyBuffer(g_EMAMediumHandle, 0, 0, 2, emaMedium) > 0 &&
       CopyBuffer(g_EMASlowHandle, 0, 0, 2, emaSlow) > 0)
    {
        // Perfect bullish alignment: EMA20 > EMA50 > EMA200
        if(emaFast[0] > emaMedium[0] && emaMedium[0] > emaSlow[0])
            g_TrendDirection = 1;
        // Perfect bearish alignment: EMA20 < EMA50 < EMA200
        else if(emaFast[0] < emaMedium[0] && emaMedium[0] < emaSlow[0])
            g_TrendDirection = -1;
    }
}

//+------------------------------------------------------------------+
//| Check for entry signals                                           |
//+------------------------------------------------------------------+
void CheckForEntry()
{
    int buyScore = 0;
    int sellScore = 0;
    int maxScore = 0;

    // === ADX FILTER (Trend Strength) ===
    if(InpUseADX)
    {
        maxScore++;
        double adx[], plusDI[], minusDI[];
        ArraySetAsSeries(adx, true);
        ArraySetAsSeries(plusDI, true);
        ArraySetAsSeries(minusDI, true);

        if(CopyBuffer(g_ADXHandle, 0, 0, 2, adx) > 0 &&
           CopyBuffer(g_ADXHandle, 1, 0, 2, plusDI) > 0 &&
           CopyBuffer(g_ADXHandle, 2, 0, 2, minusDI) > 0)
        {
            // ADX must be between min and max (strong trend but not exhausted)
            if(adx[0] >= InpADXMinLevel && adx[0] <= InpADXMaxLevel)
            {
                if(plusDI[0] > minusDI[0]) buyScore++;
                else if(minusDI[0] > plusDI[0]) sellScore++;
            }
            else
            {
                Print("ADX Filter: ", DoubleToString(adx[0], 1), " (need ", InpADXMinLevel, "-", InpADXMaxLevel, ")");
                return; // ADX is mandatory - no trade without it
            }
        }
    }

    // === EMA ALIGNMENT FILTER ===
    if(InpUseEMAFilter)
    {
        maxScore++;

        // Entry TF must align with H1 and H4
        if(g_TrendDirection == 1 && g_H1Trend == 1 && g_H4Bias == 1)
            buyScore++;
        else if(g_TrendDirection == -1 && g_H1Trend == -1 && g_H4Bias == -1)
            sellScore++;
        else
        {
            Print("EMA Filter: No alignment (M15:", g_TrendDirection, " H1:", g_H1Trend, " H4:", g_H4Bias, ")");
            if(InpEntryMode == ENTRY_CONSERVATIVE) return;
        }
    }

    // === MACD FILTER (Momentum) ===
    if(InpUseMACD)
    {
        maxScore++;
        double macd[], signal[];
        ArraySetAsSeries(macd, true);
        ArraySetAsSeries(signal, true);

        if(CopyBuffer(g_MACDHandle, 0, 0, 3, macd) > 0 &&
           CopyBuffer(g_MACDHandle, 1, 0, 3, signal) > 0)
        {
            // MACD crossover or continuation
            bool macdBullish = (macd[0] > signal[0] && macd[0] > 0);
            bool macdBearish = (macd[0] < signal[0] && macd[0] < 0);

            if(macdBullish) buyScore++;
            else if(macdBearish) sellScore++;
            else
            {
                Print("MACD Filter: No clear signal");
                if(InpEntryMode == ENTRY_CONSERVATIVE) return;
            }
        }
    }

    // === RSI FILTER (Avoid Extremes) ===
    if(InpUseRSI)
    {
        maxScore++;
        double rsi[];
        ArraySetAsSeries(rsi, true);

        if(CopyBuffer(g_RSIHandle, 0, 0, 2, rsi) > 0)
        {
            // For BUY: RSI should not be overbought
            // For SELL: RSI should not be oversold
            if(rsi[0] < InpRSIOverbought && rsi[0] > 50) buyScore++;
            else if(rsi[0] > InpRSIOversold && rsi[0] < 50) sellScore++;
            else
            {
                Print("RSI Filter: ", DoubleToString(rsi[0], 1), " (extreme zone)");
                if(InpEntryMode == ENTRY_CONSERVATIVE) return;
            }
        }
    }

    // === DETERMINE ENTRY ===
    int requiredScore;
    switch(InpEntryMode)
    {
        case ENTRY_CONSERVATIVE: requiredScore = maxScore; break;      // All filters must pass
        case ENTRY_MODERATE:     requiredScore = maxScore - 1; break;  // One filter can fail
        case ENTRY_AGGRESSIVE:   requiredScore = 2; break;             // ADX + EMA minimum
        default:                 requiredScore = maxScore; break;
    }

    if(buyScore >= requiredScore && buyScore > sellScore)
    {
        ExecuteTrade(ORDER_TYPE_BUY);
    }
    else if(sellScore >= requiredScore && sellScore > buyScore)
    {
        ExecuteTrade(ORDER_TYPE_SELL);
    }
}

//+------------------------------------------------------------------+
//| Execute Trade                                                     |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType)
{
    // Pre-trade margin check
    if(!CheckMarginForTrade())
    {
        Print("Insufficient margin");
        return;
    }

    // Get ATR for SL/TP
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(g_ATRHandle, 0, 0, 1, atr) <= 0) return;

    double atrValue = atr[0];
    double slDistance = atrValue * InpSLMultiplier;

    // Enforce min/max SL
    double minSL = InpMinSLPips * g_PipValue;
    double maxSL = InpMaxSLPips * g_PipValue;
    slDistance = MathMax(minSL, MathMin(maxSL, slDistance));

    double entryPrice, slPrice, tpPrice;

    if(orderType == ORDER_TYPE_BUY)
    {
        entryPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        slPrice = entryPrice - slDistance;
        tpPrice = entryPrice + (slDistance * InpRiskReward);
    }
    else
    {
        entryPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        slPrice = entryPrice + slDistance;
        tpPrice = entryPrice - (slDistance * InpRiskReward);
    }

    // Calculate lot size
    double lotSize = CalculateLotSize(slDistance);
    if(lotSize <= 0)
    {
        Print("Invalid lot size");
        return;
    }

    // Normalize prices
    slPrice = NormalizeDouble(slPrice, _Digits);
    tpPrice = NormalizeDouble(tpPrice, _Digits);
    entryPrice = NormalizeDouble(entryPrice, _Digits);

    string comment = StringFormat("Poutine_TF_%s_R%.1f",
                                  orderType == ORDER_TYPE_BUY ? "BUY" : "SELL",
                                  InpRiskReward);

    bool success = false;

    if(orderType == ORDER_TYPE_BUY)
        success = trade.Buy(lotSize, Symbol(), entryPrice, slPrice, tpPrice, comment);
    else
        success = trade.Sell(lotSize, Symbol(), entryPrice, slPrice, tpPrice, comment);

    if(success)
    {
        g_TradesToday++;

        Print("═══════════════════════════════════════");
        Print(orderType == ORDER_TYPE_BUY ? "BUY" : "SELL", " TREND FOLLOWING ENTRY");
        Print("Entry: ", DoubleToString(entryPrice, _Digits));
        Print("SL: ", DoubleToString(slPrice, _Digits), " (", DoubleToString(slDistance / g_PipValue, 1), " pips)");
        Print("TP: ", DoubleToString(tpPrice, _Digits), " (R:", InpRiskReward, ")");
        Print("Lot: ", DoubleToString(lotSize, 2), " | Risk: ", InpRiskPercent, "%");
        Print("Trend: M15=", g_TrendDirection, " H1=", g_H1Trend, " H4=", g_H4Bias);
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
//| Manage Open Positions (Trailing Stop)                             |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
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

        double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

        // Calculate original risk (distance from entry to SL)
        double riskDistance = MathAbs(openPrice - currentSL);
        double newSL = 0;

        // === BREAK-EVEN LOGIC ===
        if(InpUseBreakEven)
        {
            double beDistance = riskDistance * InpBreakEvenTrigger;

            if(posType == POSITION_TYPE_BUY)
            {
                // If price moved +1R in our favor, move SL to entry + small buffer
                if(bid >= openPrice + beDistance && currentSL < openPrice)
                {
                    newSL = NormalizeDouble(openPrice + (2 * _Point), _Digits);
                    Print("BREAK-EVEN activated at +", InpBreakEvenTrigger, "R");
                }
            }
            else // SELL
            {
                if(ask <= openPrice - beDistance && currentSL > openPrice)
                {
                    newSL = NormalizeDouble(openPrice - (2 * _Point), _Digits);
                    Print("BREAK-EVEN activated at +", InpBreakEvenTrigger, "R");
                }
            }
        }

        // === TRAILING STOP (only if enabled and after BE) ===
        if(InpUseTrailingStop && currentSL >= openPrice) // Only trail after BE
        {
            double atr[];
            ArraySetAsSeries(atr, true);
            if(CopyBuffer(g_ATRHandle, 0, 0, 1, atr) > 0)
            {
                double trailDistance = atr[0] * InpTrailingATRMult;

                if(posType == POSITION_TYPE_BUY)
                {
                    double potentialSL = bid - trailDistance;
                    if(potentialSL > currentSL)
                    {
                        newSL = NormalizeDouble(potentialSL, _Digits);
                    }
                }
                else
                {
                    double potentialSL = ask + trailDistance;
                    if(potentialSL < currentSL)
                    {
                        newSL = NormalizeDouble(potentialSL, _Digits);
                    }
                }
            }
        }

        // Apply new SL if changed
        if(newSL > 0 && newSL != currentSL)
        {
            if(trade.PositionModify(ticket, newSL, currentTP))
            {
                Print("SL Modified: ", DoubleToString(currentSL, _Digits), " -> ", DoubleToString(newSL, _Digits));
            }
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
        g_TradesToday = 0;

        Print("═══════════════════════════════════════");
        Print("NEW TRADING DAY");
        Print("Balance: $", DoubleToString(g_DailyStartBalance, 2));
        Print("═══════════════════════════════════════");
    }
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
//| Update Info Panel                                                 |
//+------------------------------------------------------------------+
void UpdatePanel(string status)
{
    int gmtHour, gmtMinute;
    GetGMTTime(gmtHour, gmtMinute);

    double equity = accInfo.Equity();
    double dailyPL = equity - g_DailyStartBalance;

    string trendStr = g_TrendDirection == 1 ? "BULLISH" : g_TrendDirection == -1 ? "BEARISH" : "NEUTRAL";
    string h1Str = g_H1Trend == 1 ? "UP" : g_H1Trend == -1 ? "DOWN" : "-";
    string h4Str = g_H4Bias == 1 ? "UP" : g_H4Bias == -1 ? "DOWN" : "-";

    string info = "\n";
    info += "════════════════════════════════════════\n";
    info += "   POUTINE EA v4.0 - TREND FOLLOWING\n";
    info += "   EURUSD | " + EnumToString(InpEntryMode) + "\n";
    info += "════════════════════════════════════════\n";
    info += " Status: " + status + "\n";
    info += " GMT: " + IntegerToString(gmtHour) + ":" + (gmtMinute < 10 ? "0" : "") + IntegerToString(gmtMinute) + "\n";
    info += "────────────────────────────────────────\n";
    info += " TREND ANALYSIS:\n";
    info += "   M15: " + trendStr + "\n";
    info += "   H1:  " + h1Str + " | H4: " + h4Str + "\n";
    info += "────────────────────────────────────────\n";
    info += " Equity: $" + DoubleToString(equity, 2) + "\n";
    info += " Daily P/L: " + (dailyPL >= 0 ? "+" : "") + DoubleToString(dailyPL, 2) + "\n";
    info += " Trades Today: " + IntegerToString(g_TradesToday) + "/" + IntegerToString(InpMaxTradesPerDay) + "\n";
    info += "────────────────────────────────────────\n";
    info += " Total: " + IntegerToString(g_TotalTrades) + " | WR: " +
            (g_TotalTrades > 0 ? DoubleToString((double)g_WinTrades / g_TotalTrades * 100, 1) : "0") + "%\n";
    info += "════════════════════════════════════════\n";

    Comment(info);
}

//+------------------------------------------------------------------+
//| Print Initialization Info                                         |
//+------------------------------------------------------------------+
void PrintInitInfo()
{
    Print("═══════════════════════════════════════════════════");
    Print("     POUTINE EA v4.0 - EURUSD TREND FOLLOWING");
    Print("         ADX + EMA + MACD + RSI System");
    Print("═══════════════════════════════════════════════════");
    Print("Symbol: ", Symbol());
    Print("Entry TF: ", EnumToString(InpEntryTF));
    Print("Trend TF: ", EnumToString(InpTrendTF));
    Print("Bias TF: ", EnumToString(InpBiasTF));
    Print("Entry Mode: ", EnumToString(InpEntryMode));
    Print("Risk: ", InpRiskPercent, "% | R:R = 1:", InpRiskReward);
    Print("═══════════════════════════════════════════════════");
    Print("FILTERS:");
    if(InpUseADX) Print("  ADX: ON (", InpADXMinLevel, "-", InpADXMaxLevel, ")");
    else Print("  ADX: OFF");
    if(InpUseEMAFilter) Print("  EMA: ON (", InpEMAFast, "/", InpEMAMedium, "/", InpEMASlow, ")");
    else Print("  EMA: OFF");
    Print("  MACD: ", InpUseMACD ? "ON" : "OFF");
    if(InpUseRSI) Print("  RSI: ON (", InpRSIOversold, "-", InpRSIOverbought, ")");
    else Print("  RSI: OFF");
    Print("═══════════════════════════════════════════════════");
    Print("SESSION: ", InpSessionStartHour, ":00 - ", InpSessionEndHour, ":00 GMT");
    Print("Max Trades/Day: ", InpMaxTradesPerDay);
    Print("═══════════════════════════════════════════════════");
    Print("POUTINE EURUSD EA INITIALIZED");
    Print("═══════════════════════════════════════════════════");
}
//+------------------------------------------------------------------+
