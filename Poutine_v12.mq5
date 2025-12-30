//+------------------------------------------------------------------+
//|                                               Poutine_GBPUSD.mq5 |
//|                      LONDON BREAKOUT STRATEGY FOR GBPUSD         |
//|                   https://github.com/tradingluca31-boop/Poutine  |
//+------------------------------------------------------------------+
#property copyright "Poutine EA v12.0 - LONDON BREAKOUT GBPUSD"
#property link      "https://github.com/tradingluca31-boop/Poutine"
#property version   "12.00"
#property description "=== POUTINE EA v12.0 - LONDON BREAKOUT GBPUSD ==="
#property description "RSI + EMA84 + SMMA50 Filters | R:R 1.5"
#property description "Pro-grade filters from top EAs | FTMO Compatible"
#property description "Optimized for GBP/USD - Best pair for London Breakout"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - OPTIMIZED FOR GBPUSD                          |
//+------------------------------------------------------------------+
input group "══════════ RISK MANAGEMENT ══════════"
input double   InpRiskPercent       = 1.0;              // Risk % Per Trade
input double   InpRiskReward        = 3.0;              // Risk:Reward
input bool     InpUseFTMOLotCalc    = true;             // FTMO Mode: Lot sur Capital Initial (pas de compounding)
input double   InpMaxDailyLossPct   = 4.0;              // Max Daily Loss % (FTMO: 5%)
input double   InpMaxTotalDDPct     = 100.0;            // Max Total Drawdown % (disabled for backtest)
input bool     InpUseFTMOProtection = false;            // Enable FTMO Protection (OFF for backtest)

input group "══════════ TRADE SETTINGS ══════════"
input int      InpMagicNumber       = 202412;           // Magic Number (v12.0 RSI)
input int      InpMaxTradesPerDay   = 2;                // Max Trades Per Day
input bool     InpUseTrailingStop   = false;            // Use Trailing Stop (OFF = let TP hit)
input double   InpTrailingATRMult   = 2.0;              // Trailing Stop ATR Multiplier

input group "══════════ ASIAN RANGE (Build the Box) ══════════"
input int      InpAsianStartHour    = 0;                // Asian Range Start (GMT) - Midnight
input int      InpAsianEndHour      = 6;                // Asian Range End (GMT) - 6 hours box

input group "══════════ LONDON ENTRY WINDOW ══════════"
input int      InpLondonStartHour   = 7;                // London Entry Start (GMT)
input int      InpLondonEndHour     = 20;               // London Entry End (GMT)
input bool     InpUseForceClose     = true;             // Force Close at 20h GMT (ON)
input int      InpForceCloseHour    = 20;               // Force Close Hour (GMT)

input group "═══════════════════════════════════════════════════════════"
input group "                    ★★★ SIGNAUX D'ENTRÉE ★★★                    "
input group "═══════════════════════════════════════════════════════════"

input group "══════════ SIGNAL 1: BREAKOUT ASIAN RANGE ══════════"
input bool     InpUseBreakoutSignal = true;             // Signal Breakout ON
input int      InpBreakoutBuffer    = 10;               // Breakout Buffer (pips)
input int      InpMinBoxSize        = 15;               // Min Box Size (pips)
input int      InpMaxBoxSize        = 60;               // Max Box Size (pips)
input bool     InpWaitForClose      = true;             // Wait for candle CLOSE outside range (safer)

input group "══════════ SIGNAL 2: EMA 20/55 TREND CONFIRMATION ══════════"
input bool     InpUseEMACrossSignal = true;             // EMA Trend Confirmation ON (EMA20>55=BUY, EMA20<55=SELL)
input int      InpEMACrossFast      = 20;               // EMA Fast Period
input int      InpEMACrossSlow      = 55;               // EMA Slow Period

input group "══════════ SIGNAL 3: RETEST ENTRY ══════════"
input bool     InpUseRetestEntry    = true;             // Signal Retest ON (2ème entrée après pullback)
input int      InpRetestTolerance   = 15;               // Tolerance retest (pips)
input int      InpRetestMinBars     = 1;                // Min bars après breakout

input group "══════════ SIGNAL 4: RSI MOMENTUM (Quant Fund Signal) ══════════"
input bool     InpUseRSIMomentum    = true;             // RSI Momentum ON (RSI>50=BUY, RSI<50=SELL)
input int      InpRSIPeriod         = 14;               // RSI Period (14 standard)
input ENUM_TIMEFRAMES InpRSITimeframe = PERIOD_M15;     // RSI Timeframe

input group "══════════ SIGNAL 5: ATR EXPANSION (Volatility Confirmation) ══════════"
input bool     InpUseATRExpansion   = true;             // ATR Expansion ON (volatilité suffisante)
input int      InpATRExpPeriod      = 14;               // ATR Period
input int      InpATRAvgPeriod      = 20;               // ATR Average Period (pour comparaison)
input double   InpATRExpMultiplier  = 1.2;              // ATR >= 120% de la moyenne = volatilité OK

input group "══════════ SYSTÈME DE VOTE SIGNAUX ══════════"
input int      InpMinSignalsRequired = 1;               // Min signaux requis (1=un seul suffit, 2=confirmation)

input group "═══════════════════════════════════════════════════════════"
input group "                    ★★★ GESTION DU TRADE ★★★                  "
input group "═══════════════════════════════════════════════════════════"

input group "══════════ SL PLACEMENT ══════════"
input bool     InpUseFixedSL        = true;             // Use Fixed SL (ON) vs Box Opposite (OFF)
input int      InpFixedSLPips       = 25;               // Fixed SL Distance (pips)

input group "══════════ BREAK-EVEN ══════════"
input bool     InpUseBreakEven      = false;            // Break-Even OFF
input double   InpBreakEvenTrigger  = 1.0;              // Trigger BE at 1R profit

input group "══════════ MAX LOSS/PROFIT PROTECTION ══════════"
input bool     InpUseMaxLossProtection = true;          // Max Loss Protection ON (ferme si perte ≥ seuil)
input double   InpMaxLossPerTrade   = 100.0;            // Max Loss Per Trade ($) = -$100 max
input int      InpMaxLossPips       = 30;               // Max Loss Pips (backup) = ferme si > 30 pips contre
input bool     InpUseMaxProfitProtection = true;        // Max Profit Protection ON (ferme si gain ≥ seuil)
input double   InpMaxProfitPerTrade = 300.0;            // Max Profit Per Trade ($) = +$300 (3R)

input group "══════════ BROKER SETTINGS ══════════"
input bool     InpAutoDetectGMT     = true;             // Auto-Detect GMT (LIVE) - Manual en backtest
input int      InpBrokerGMTOffset   = 2;                // Broker GMT Offset (backtest uniquement)

input group "═══════════════════════════════════════════════════════════"
input group "                    ★★★ FILTRES ★★★                           "
input group "═══════════════════════════════════════════════════════════"

input group "══════════ SYSTÈME DE VOTE FILTRES ══════════"
input int      InpMinFiltersRequired = 2;               // Min filtres validés requis (sur les actifs)

input group "══════════ FILTRE 0: SPREAD ══════════"
input int      InpMaxSpreadPips     = 3;                // Max Spread (pips) - 3 for GBPUSD

input group "══════════ FILTRE 1: SMMA 100 H1 (Tendance) ══════════"
input bool     InpUseTrendFilter    = true;             // Filtre SMMA ON
input int      InpSMMAPeriod        = 100;              // SMMA Period
input bool     InpUseSlopeFilter    = false;            // SMMA Slope Filter OFF
input int      InpSlopeLookback     = 5;                // Lookback bars for slope (5 = ~5H on H1)
input double   InpMinSlopePips      = 5.0;              // Min slope in pips (SMMA doit bouger de X pips)
input bool     InpUseDistanceFilter = false;            // Price Distance from MA OFF
input double   InpMinDistancePips   = 10.0;             // Min distance from SMMA (prix pas trop proche)

input group "══════════ FILTRE 2: ADX (Force tendance) ══════════"
input bool     InpUseADXFilter      = true;             // Filtre ADX ON
input int      InpADXPeriod         = 14;               // ADX Period
input int      InpADXMinLevel       = 25;               // Min ADX (25 = strong trend)
input bool     InpADXRising         = true;             // ADX Rising ON (trend strengthening)
input bool     InpUseDIDirection    = false;            // DI Direction OFF

input group "══════════ FILTRE 3: VOLUME ══════════"
input bool     InpUseVolumeFilter   = true;             // Filtre Volume ON
input int      InpVolumePeriod      = 20;               // Volume MA Period
input double   InpVolumeMultiplier  = 1.2;              // Volume >= 120% moyenne

input group "══════════ FILTRE 4: EMA 50 DAILY (Higher TF Trend) ══════════"
input bool     InpUseEMA50D1Filter  = true;             // Filtre EMA 50 D1 ON (trade avec trend Daily)
input int      InpEMA50D1Period     = 50;               // EMA Period sur D1

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

// Indicator handles
int            g_ATRHandle = INVALID_HANDLE;
int            g_SMMAHandle = INVALID_HANDLE;
int            g_ADXHandle = INVALID_HANDLE;

// Trade management
int            g_TradesToday = 0;
datetime       g_LastTradeDate = 0;
int            g_BrokerGMTOffset = 0;
double         g_DailyStartBalance = 0;
double         g_InitialBalance = 0;

// Asian Range (The Box)
double         g_AsianHigh = 0;
double         g_AsianLow = 0;
double         g_BoxSize = 0;
bool           g_BoxReady = false;
datetime       g_BoxDate = 0;
bool           g_BreakoutTriggered = false;

// Statistics
int            g_TotalTrades = 0;
int            g_WinTrades = 0;
int            g_LossTrades = 0;
double         g_TotalProfit = 0;
string         g_Status = "INITIALIZING";

// EMA 20/55 H1 Cross Signal (signal)
int            g_EMA20H1Handle = INVALID_HANDLE;
int            g_EMA55H1Handle = INVALID_HANDLE;
bool           g_EMACrossSignalTriggered = false;   // Evite de re-entrer sur le même cross
datetime       g_LastEMACrossTime = 0;              // Heure du dernier cross

// RSI Momentum Signal (Quant Fund Signal)
int            g_RSIHandle = INVALID_HANDLE;

// ATR Expansion Signal (Volatility Confirmation)
int            g_ATRExpHandle = INVALID_HANDLE;

// EMA 50 Daily Filter (Higher Timeframe Trend)
int            g_EMA50D1Handle = INVALID_HANDLE;

// Break-Even tracking (stores original risk distance per trade)
double         g_OriginalRiskDistance = 0;

// Retest Entry tracking
bool           g_RetestPending = false;          // Un retest est en attente
ENUM_ORDER_TYPE g_RetestDirection;               // Direction du retest (BUY ou SELL)
double         g_RetestLevel = 0;                // Niveau à retester (Asian High ou Low)
datetime       g_BreakoutTime = 0;               // Heure du breakout initial
bool           g_RetestTriggered = false;        // Retest déjà exécuté aujourd'hui
double         g_OriginalEntryPrice = 0;
bool           g_BEActivated = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    // Calculate pip value for GBPUSD (5 digits)
    g_PipDigits = (_Digits == 5 || _Digits == 3) ? 1 : 0;
    g_PipValue = _Point * MathPow(10, g_PipDigits);

    // Validate symbol - GBPUSD is optimal
    string symbol = Symbol();
    if(StringFind(symbol, "GBP") < 0 || StringFind(symbol, "USD") < 0)
    {
        Print("WARNING: Poutine GBPUSD EA is optimized for GBPUSD!");
        Print("Current symbol: ", symbol);
        Print("GBP/USD is THE BEST pair for London Breakout strategy.");
    }

    // Initialize trade object
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_IOC);

    // Initialize ATR indicator (used for trailing stop)
    g_ATRHandle = iATR(Symbol(), PERIOD_H1, 14);
    if(g_ATRHandle == INVALID_HANDLE)
    {
        Print("Failed to create ATR indicator");
        return(INIT_FAILED);
    }

    // ALWAYS Initialize SMMA indicator (needed even if filter toggled later)
    g_SMMAHandle = iMA(Symbol(), PERIOD_H1, InpSMMAPeriod, 0, MODE_SMMA, PRICE_CLOSE);
    if(g_SMMAHandle == INVALID_HANDLE)
    {
        Print("Failed to create SMMA indicator");
        return(INIT_FAILED);
    }

    // ALWAYS Initialize ADX indicator for trend strength filter
    g_ADXHandle = iADX(Symbol(), PERIOD_H1, InpADXPeriod);
    if(g_ADXHandle == INVALID_HANDLE)
    {
        Print("Failed to create ADX indicator");
        return(INIT_FAILED);
    }

    // Initialize EMA 20/55 on H1 for EMA Cross SIGNAL
    g_EMA20H1Handle = iMA(Symbol(), PERIOD_H1, InpEMACrossFast, 0, MODE_EMA, PRICE_CLOSE);
    if(g_EMA20H1Handle == INVALID_HANDLE)
    {
        Print("Failed to create EMA 20 H1 indicator");
        return(INIT_FAILED);
    }

    g_EMA55H1Handle = iMA(Symbol(), PERIOD_H1, InpEMACrossSlow, 0, MODE_EMA, PRICE_CLOSE);
    if(g_EMA55H1Handle == INVALID_HANDLE)
    {
        Print("Failed to create EMA 55 H1 indicator");
        return(INIT_FAILED);
    }

    // Initialize RSI for Momentum Signal (Quant Fund Signal)
    g_RSIHandle = iRSI(Symbol(), InpRSITimeframe, InpRSIPeriod, PRICE_CLOSE);
    if(g_RSIHandle == INVALID_HANDLE)
    {
        Print("Failed to create RSI indicator");
        return(INIT_FAILED);
    }

    // Initialize ATR for Volatility Expansion Signal
    g_ATRExpHandle = iATR(Symbol(), PERIOD_M15, InpATRExpPeriod);
    if(g_ATRExpHandle == INVALID_HANDLE)
    {
        Print("Failed to create ATR Expansion indicator");
        return(INIT_FAILED);
    }

    // Initialize EMA 50 on D1 for Higher Timeframe Trend Filter
    g_EMA50D1Handle = iMA(Symbol(), PERIOD_D1, InpEMA50D1Period, 0, MODE_EMA, PRICE_CLOSE);
    if(g_EMA50D1Handle == INVALID_HANDLE)
    {
        Print("Failed to create EMA 50 D1 indicator");
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
    if(g_ATRHandle != INVALID_HANDLE) IndicatorRelease(g_ATRHandle);
    if(g_SMMAHandle != INVALID_HANDLE) IndicatorRelease(g_SMMAHandle);
    if(g_ADXHandle != INVALID_HANDLE) IndicatorRelease(g_ADXHandle);
    if(g_EMA20H1Handle != INVALID_HANDLE) IndicatorRelease(g_EMA20H1Handle);
    if(g_EMA55H1Handle != INVALID_HANDLE) IndicatorRelease(g_EMA55H1Handle);
    if(g_RSIHandle != INVALID_HANDLE) IndicatorRelease(g_RSIHandle);
    if(g_ATRExpHandle != INVALID_HANDLE) IndicatorRelease(g_ATRExpHandle);
    if(g_EMA50D1Handle != INVALID_HANDLE) IndicatorRelease(g_EMA50D1Handle);

    Comment("");

    Print("═══════════════════════════════════════");
    Print("POUTINE GBPUSD v11.0 LONDON BREAKOUT STOPPED");
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
    // Check for new day - reset box and trades
    CheckNewDay();

    // Get GMT time
    int gmtHour, gmtMinute;
    GetGMTTime(gmtHour, gmtMinute);

    // === PHASE 1: BUILD THE BOX (Asian Session 00:00 - 06:00 GMT) ===
    if(gmtHour >= InpAsianStartHour && gmtHour < InpAsianEndHour)
    {
        BuildAsianBox();
        g_Status = "BUILDING BOX";
        if(InpShowPanel) UpdatePanel();
        return;
    }

    // === PHASE 2: LONDON ENTRY WINDOW (07:00 - 10:00 GMT) ===
    if(gmtHour >= InpLondonStartHour && gmtHour < InpLondonEndHour)
    {
        // Check if box is valid
        if(!ValidateBox())
        {
            g_Status = "BOX INVALID";
            if(InpShowPanel) UpdatePanel();
            ManageOpenPositions();
            return;
        }

        // FTMO Protection
        if(InpUseFTMOProtection && !CheckFTMOLimits())
        {
            g_Status = "FTMO LIMIT";
            if(InpShowPanel) UpdatePanel();
            return;
        }

        // Max trades per day
        if(g_TradesToday >= InpMaxTradesPerDay || g_BreakoutTriggered)
        {
            g_Status = "WAITING (TRADED)";
            if(InpShowPanel) UpdatePanel();
            ManageOpenPositions();
            return;
        }

        // Spread filter (early exit for efficiency)
        double spreadPips = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * _Point / g_PipValue;
        if(spreadPips > InpMaxSpreadPips)
        {
            g_Status = "SPREAD: " + DoubleToString(spreadPips, 1);
            if(InpShowPanel) UpdatePanel();
            ManageOpenPositions();
            return;
        }

        // Check all signals with unified voting system
        g_Status = "LONDON - SCANNING";
        if(!HasOpenPosition())
        {
            CheckSignalsAndExecute();
        }
    }

    // === PHASE 3: TRADE MANAGEMENT (10:00 - 17:00 GMT) ===
    if(gmtHour >= InpLondonEndHour && gmtHour < InpForceCloseHour)
    {
        g_Status = "MANAGING";

        // Continue checking for retest signal during management phase
        if(g_RetestPending && !HasOpenPosition())
        {
            CheckSignalsAndExecute();
        }
    }

    // === PHASE 4: FORCE CLOSE (optional) ===
    if(InpUseForceClose && gmtHour >= InpForceCloseHour)
    {
        ForceCloseAllPositions("End of Day");
        g_Status = "CLOSED - EOD";
    }

    // Manage open positions (trailing, BE)
    ManageOpenPositions();

    // Update panel
    if(InpShowPanel) UpdatePanel();
}

//+------------------------------------------------------------------+
//| Build Asian Range (The Box)                                       |
//+------------------------------------------------------------------+
void BuildAsianBox()
{
    // Get current day
    datetime currentTime = TimeCurrent();
    datetime today = StringToTime(TimeToString(currentTime, TIME_DATE));

    // Reset box if new day
    if(g_BoxDate != today)
    {
        g_AsianHigh = 0;
        g_AsianLow = 999999;
        g_BoxDate = today;
        g_BoxReady = false;
        g_BreakoutTriggered = false;
    }

    // Get current price
    double high = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double low = SymbolInfoDouble(Symbol(), SYMBOL_BID);

    // Update box
    if(high > g_AsianHigh) g_AsianHigh = high;
    if(low < g_AsianLow) g_AsianLow = low;

    // Calculate box size
    g_BoxSize = (g_AsianHigh - g_AsianLow) / g_PipValue;
}

//+------------------------------------------------------------------+
//| Validate Asian Box                                                |
//+------------------------------------------------------------------+
bool ValidateBox()
{
    // Check if box was built
    if(g_AsianHigh == 0 || g_AsianLow == 999999 || g_AsianLow >= g_AsianHigh)
    {
        return false;
    }

    // Recalculate box size
    g_BoxSize = (g_AsianHigh - g_AsianLow) / g_PipValue;

    // Check box size limits
    if(g_BoxSize < InpMinBoxSize)
    {
        Print("Box too small: ", DoubleToString(g_BoxSize, 1), " pips < ", InpMinBoxSize);
        return false;
    }

    if(g_BoxSize > InpMaxBoxSize)
    {
        Print("Box too large: ", DoubleToString(g_BoxSize, 1), " pips > ", InpMaxBoxSize);
        return false;
    }

    g_BoxReady = true;
    return true;
}

//+------------------------------------------------------------------+
//| Check for Breakout                                                |
//+------------------------------------------------------------------+
void CheckForBreakout()
{
    double breakoutBuffer = InpBreakoutBuffer * g_PipValue;
    double breakoutHighLevel = g_AsianHigh + breakoutBuffer;
    double breakoutLowLevel = g_AsianLow - breakoutBuffer;

    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

    bool buyBreakout = false;
    bool sellBreakout = false;

    if(InpWaitForClose)
    {
        // Wait for M15 candle to CLOSE outside range
        static datetime lastBarTime = 0;
        datetime currentBarTime = iTime(Symbol(), PERIOD_M15, 0);

        if(currentBarTime != lastBarTime)
        {
            lastBarTime = currentBarTime;

            // Check previous candle close
            double prevClose = iClose(Symbol(), PERIOD_M15, 1);
            double prevHigh = iHigh(Symbol(), PERIOD_M15, 1);
            double prevLow = iLow(Symbol(), PERIOD_M15, 1);

            // BUY: Previous candle closed above Asian High
            if(prevClose > breakoutHighLevel && prevLow <= g_AsianHigh)
            {
                buyBreakout = true;
                Print("BREAKOUT UP: Candle closed at ", DoubleToString(prevClose, _Digits),
                      " above ", DoubleToString(breakoutHighLevel, _Digits));
            }
            // SELL: Previous candle closed below Asian Low
            else if(prevClose < breakoutLowLevel && prevHigh >= g_AsianLow)
            {
                sellBreakout = true;
                Print("BREAKOUT DOWN: Candle closed at ", DoubleToString(prevClose, _Digits),
                      " below ", DoubleToString(breakoutLowLevel, _Digits));
            }
        }
    }
    else
    {
        // Immediate breakout (less safe, more signals)
        if(bid > breakoutHighLevel)
        {
            buyBreakout = true;
        }
        else if(ask < breakoutLowLevel)
        {
            sellBreakout = true;
        }
    }

    // Execute trade
    if(buyBreakout)
    {
        ExecuteBreakoutTrade(ORDER_TYPE_BUY);
    }
    else if(sellBreakout)
    {
        ExecuteBreakoutTrade(ORDER_TYPE_SELL);
    }
}

//+------------------------------------------------------------------+
//| SIGNAL 2: Check for EMA 20/55 Cross on H1                         |
//| Cross UP = BUY signal, Cross DOWN = SELL signal                   |
//+------------------------------------------------------------------+
void CheckEMACrossSignal()
{
    if(!InpUseEMACrossSignal) return;

    // Vérifier si on a déjà une position ouverte
    if(HasOpenPosition()) return;

    // Vérifier si on n'a pas dépassé le max trades
    if(g_TradesToday >= InpMaxTradesPerDay) return;

    double ema20[], ema55[];
    ArraySetAsSeries(ema20, true);
    ArraySetAsSeries(ema55, true);

    // Get EMA values (current and previous bar)
    if(CopyBuffer(g_EMA20H1Handle, 0, 0, 3, ema20) < 3) return;
    if(CopyBuffer(g_EMA55H1Handle, 0, 0, 3, ema55) < 3) return;

    // Detect crossover on the PREVIOUS bar (bar 1)
    // Cross UP: EMA20 was below EMA55, now above
    bool crossUp = (ema20[2] < ema55[2]) && (ema20[1] > ema55[1]);
    // Cross DOWN: EMA20 was above EMA55, now below
    bool crossDown = (ema20[2] > ema55[2]) && (ema20[1] < ema55[1]);

    // Avoid re-entry on same cross
    datetime currentBarTime = iTime(Symbol(), PERIOD_H1, 1);
    if(currentBarTime == g_LastEMACrossTime) return;

    if(crossUp)
    {
        g_LastEMACrossTime = currentBarTime;
        Print("═══════════════════════════════════════");
        Print("★ SIGNAL EMA CROSS UP ★");
        Print("EMA20: ", DoubleToString(ema20[1], _Digits), " crossed ABOVE EMA55: ", DoubleToString(ema55[1], _Digits));
        ExecuteSignalTrade(ORDER_TYPE_BUY, "EMA_CROSS");
    }
    else if(crossDown)
    {
        g_LastEMACrossTime = currentBarTime;
        Print("═══════════════════════════════════════");
        Print("★ SIGNAL EMA CROSS DOWN ★");
        Print("EMA20: ", DoubleToString(ema20[1], _Digits), " crossed BELOW EMA55: ", DoubleToString(ema55[1], _Digits));
        ExecuteSignalTrade(ORDER_TYPE_SELL, "EMA_CROSS");
    }
}

//+------------------------------------------------------------------+
//| Execute Trade from Signal (with filter voting system)             |
//+------------------------------------------------------------------+
void ExecuteSignalTrade(ENUM_ORDER_TYPE orderType, string signalName)
{
    // Use unified filter voting system
    if(!CheckFiltersWithVoting(orderType, signalName))
    {
        return;
    }

    // Pre-trade margin check
    if(!CheckMarginForTrade())
    {
        Print("Insufficient margin");
        return;
    }

    // Calculate entry, SL, TP
    double entryPrice, slPrice, tpPrice;
    double slDistance;

    if(orderType == ORDER_TYPE_BUY)
    {
        entryPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

        if(InpUseFixedSL)
        {
            slDistance = InpFixedSLPips * g_PipValue;
            slPrice = entryPrice - slDistance;
        }
        else
        {
            slPrice = g_AsianLow - (InpBreakoutBuffer * g_PipValue);
            slDistance = entryPrice - slPrice;
        }
        tpPrice = entryPrice + (slDistance * InpRiskReward);
    }
    else
    {
        entryPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);

        if(InpUseFixedSL)
        {
            slDistance = InpFixedSLPips * g_PipValue;
            slPrice = entryPrice + slDistance;
        }
        else
        {
            slPrice = g_AsianHigh + (InpBreakoutBuffer * g_PipValue);
            slDistance = slPrice - entryPrice;
        }
        tpPrice = entryPrice - (slDistance * InpRiskReward);
    }

    // Validate SL distance
    if(slDistance <= 0 || slDistance / g_PipValue > 150)
    {
        Print("Invalid SL distance");
        return;
    }

    double lotSize = CalculateLotSize(slDistance);
    if(lotSize <= 0) return;

    // Normalize prices
    slPrice = NormalizeDouble(slPrice, _Digits);
    tpPrice = NormalizeDouble(tpPrice, _Digits);
    entryPrice = NormalizeDouble(entryPrice, _Digits);

    string comment = StringFormat("Poutine_%s_%s_R%.1f",
                                  signalName,
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

        g_OriginalRiskDistance = slDistance;
        g_OriginalEntryPrice = entryPrice;
        g_BEActivated = false;

        Print("════════ ", signalName, " TRADE EXECUTED ════════");
        Print("Direction: ", orderType == ORDER_TYPE_BUY ? "BUY" : "SELL");
        Print("Entry: ", DoubleToString(entryPrice, _Digits));
        Print("SL: ", DoubleToString(slPrice, _Digits), " (", DoubleToString(slDistance / g_PipValue, 1), " pips)");
        Print("TP: ", DoubleToString(tpPrice, _Digits));
        Print("Lot: ", DoubleToString(lotSize, 2));
        Print("═══════════════════════════════════════");
    }
    else
    {
        Print("Order failed: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Check for Retest Entry (2ème entrée professionnelle)              |
//| Après un breakout, le prix revient souvent tester le niveau cassé |
//| Si rebond confirmé = 2ème entrée de qualité                       |
//+------------------------------------------------------------------+
void CheckForRetest()
{
    if(!InpUseRetestEntry || !g_RetestPending || g_RetestTriggered) return;

    // Vérifier si assez de temps s'est écoulé depuis le breakout
    int barsSinceBreakout = Bars(Symbol(), PERIOD_M15, g_BreakoutTime, TimeCurrent());
    if(barsSinceBreakout < InpRetestMinBars) return;

    // Vérifier si on a déjà une position ouverte
    if(HasOpenPosition()) return;

    // Vérifier si on n'a pas dépassé le max trades
    if(g_TradesToday >= InpMaxTradesPerDay) return;

    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double tolerance = InpRetestTolerance * g_PipValue;

    // Pour un BUY: le prix doit revenir PROCHE du Asian High puis repartir
    if(g_RetestDirection == ORDER_TYPE_BUY)
    {
        // Vérifier si le prix actuel est revenu proche du niveau
        // OU si une des dernières bougies a touché le niveau
        double prevLow1 = iLow(Symbol(), PERIOD_M15, 1);
        double prevLow2 = iLow(Symbol(), PERIOD_M15, 2);
        double currentBid = bid;

        // Condition simple: le low d'une des dernières bougies a touché la zone de retest
        // ET le prix actuel est maintenant AU-DESSUS du niveau (rebond)
        bool touchedZone = (prevLow1 <= g_RetestLevel + tolerance) ||
                           (prevLow2 <= g_RetestLevel + tolerance);
        bool priceAbove = currentBid > g_RetestLevel;

        if(touchedZone && priceAbove)
        {
            Print("═══════════════════════════════════════");
            Print("RETEST BUY: Prix touché zone ", DoubleToString(g_RetestLevel, _Digits));
            Print("Low récent: ", DoubleToString(MathMin(prevLow1, prevLow2), _Digits));
            Print("Prix actuel: ", DoubleToString(currentBid, _Digits), " > Level = REBOND");
            ExecuteRetestTrade(ORDER_TYPE_BUY);
            return;
        }
    }
    // Pour un SELL: le prix doit revenir PROCHE du Asian Low puis repartir
    else if(g_RetestDirection == ORDER_TYPE_SELL)
    {
        double prevHigh1 = iHigh(Symbol(), PERIOD_M15, 1);
        double prevHigh2 = iHigh(Symbol(), PERIOD_M15, 2);
        double currentBid = bid;

        // Condition simple: le high d'une des dernières bougies a touché la zone de retest
        // ET le prix actuel est maintenant EN-DESSOUS du niveau (rebond)
        bool touchedZone = (prevHigh1 >= g_RetestLevel - tolerance) ||
                           (prevHigh2 >= g_RetestLevel - tolerance);
        bool priceBelow = currentBid < g_RetestLevel;

        if(touchedZone && priceBelow)
        {
            Print("═══════════════════════════════════════");
            Print("RETEST SELL: Prix touché zone ", DoubleToString(g_RetestLevel, _Digits));
            Print("High récent: ", DoubleToString(MathMax(prevHigh1, prevHigh2), _Digits));
            Print("Prix actuel: ", DoubleToString(currentBid, _Digits), " < Level = REBOND");
            ExecuteRetestTrade(ORDER_TYPE_SELL);
            return;
        }
    }
}

//+------------------------------------------------------------------+
//| Execute Retest Trade (même paramètres que breakout initial)       |
//+------------------------------------------------------------------+
void ExecuteRetestTrade(ENUM_ORDER_TYPE orderType)
{
    // Use unified filter voting system
    if(!CheckFiltersWithVoting(orderType, "RETEST"))
    {
        return;
    }

    double entryPrice, slPrice, tpPrice;
    double slDistance;

    if(orderType == ORDER_TYPE_BUY)
    {
        entryPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

        if(InpUseFixedSL)
        {
            slDistance = InpFixedSLPips * g_PipValue;
            slPrice = entryPrice - slDistance;
        }
        else
        {
            slPrice = g_AsianLow - (InpBreakoutBuffer * g_PipValue);
            slDistance = entryPrice - slPrice;
        }
        tpPrice = entryPrice + (slDistance * InpRiskReward);
    }
    else
    {
        entryPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);

        if(InpUseFixedSL)
        {
            slDistance = InpFixedSLPips * g_PipValue;
            slPrice = entryPrice + slDistance;
        }
        else
        {
            slPrice = g_AsianHigh + (InpBreakoutBuffer * g_PipValue);
            slDistance = slPrice - entryPrice;
        }
        tpPrice = entryPrice - (slDistance * InpRiskReward);
    }

    // Validate SL distance
    if(slDistance <= 0 || slDistance / g_PipValue > 150)
    {
        Print("RETEST: Invalid SL distance");
        return;
    }

    double lotSize = CalculateLotSize(slDistance);
    if(lotSize <= 0)
    {
        Print("RETEST: Invalid lot size");
        return;
    }

    // Normalize prices
    slPrice = NormalizeDouble(slPrice, _Digits);
    tpPrice = NormalizeDouble(tpPrice, _Digits);
    entryPrice = NormalizeDouble(entryPrice, _Digits);

    string comment = StringFormat("Poutine_RETEST_%s_R%.1f",
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
        g_RetestTriggered = true;
        g_RetestPending = false;

        // Store original risk for BE
        g_OriginalRiskDistance = slDistance;
        g_OriginalEntryPrice = entryPrice;
        g_BEActivated = false;

        Print("════════ RETEST ENTRY EXECUTED ════════");
        Print("Direction: ", orderType == ORDER_TYPE_BUY ? "BUY" : "SELL");
        Print("Retest Level: ", DoubleToString(g_RetestLevel, _Digits));
        Print("Entry: ", DoubleToString(entryPrice, _Digits));
        Print("SL: ", DoubleToString(slPrice, _Digits), " (", DoubleToString(slDistance / g_PipValue, 1), " pips)");
        Print("TP: ", DoubleToString(tpPrice, _Digits));
        Print("Lot: ", DoubleToString(lotSize, 2));
        Print("═══════════════════════════════════════");
    }
    else
    {
        Print("RETEST Order failed: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| SIGNAL DETECTION: Check if Breakout signal is triggered            |
//| Returns: ORDER_TYPE_BUY, ORDER_TYPE_SELL, or -1 (no signal)        |
//+------------------------------------------------------------------+
int IsBreakoutSignal()
{
    if(!InpUseBreakoutSignal) return -1;
    if(!g_BoxReady) return -1;

    double breakoutBuffer = InpBreakoutBuffer * g_PipValue;
    double breakoutHighLevel = g_AsianHigh + breakoutBuffer;
    double breakoutLowLevel = g_AsianLow - breakoutBuffer;

    if(InpWaitForClose)
    {
        // Check previous M15 candle close
        double prevClose = iClose(Symbol(), PERIOD_M15, 1);
        double prevHigh = iHigh(Symbol(), PERIOD_M15, 1);
        double prevLow = iLow(Symbol(), PERIOD_M15, 1);

        // BUY: Previous candle closed above Asian High
        if(prevClose > breakoutHighLevel && prevLow <= g_AsianHigh)
        {
            return ORDER_TYPE_BUY;
        }
        // SELL: Previous candle closed below Asian Low
        if(prevClose < breakoutLowLevel && prevHigh >= g_AsianLow)
        {
            return ORDER_TYPE_SELL;
        }
    }
    else
    {
        double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

        if(bid > breakoutHighLevel) return ORDER_TYPE_BUY;
        if(ask < breakoutLowLevel) return ORDER_TYPE_SELL;
    }

    return -1;
}

//+------------------------------------------------------------------+
//| SIGNAL CONFIRMATION: Check EMA TREND direction                     |
//| Returns: ORDER_TYPE_BUY if bullish, ORDER_TYPE_SELL if bearish     |
//| This is a CONFIRMATION signal, not a trigger!                      |
//| EMA20 > EMA55 = Bullish trend = confirms BUY breakouts             |
//| EMA20 < EMA55 = Bearish trend = confirms SELL breakouts            |
//+------------------------------------------------------------------+
int IsEMATrendConfirmation()
{
    if(!InpUseEMACrossSignal) return -1;

    double ema20[], ema55[];
    ArraySetAsSeries(ema20, true);
    ArraySetAsSeries(ema55, true);

    if(CopyBuffer(g_EMA20H1Handle, 0, 0, 1, ema20) < 1) return -1;
    if(CopyBuffer(g_EMA55H1Handle, 0, 0, 1, ema55) < 1) return -1;

    // Check current trend direction (not the cross!)
    if(ema20[0] > ema55[0])
    {
        // EMA20 above EMA55 = BULLISH trend
        return ORDER_TYPE_BUY;
    }
    else if(ema20[0] < ema55[0])
    {
        // EMA20 below EMA55 = BEARISH trend
        return ORDER_TYPE_SELL;
    }

    return -1;
}

//+------------------------------------------------------------------+
//| SIGNAL DETECTION: Check if Retest signal is triggered              |
//| Returns: ORDER_TYPE_BUY, ORDER_TYPE_SELL, or -1 (no signal)        |
//+------------------------------------------------------------------+
int IsRetestSignal()
{
    if(!InpUseRetestEntry || !g_RetestPending || g_RetestTriggered) return -1;

    int barsSinceBreakout = Bars(Symbol(), PERIOD_M15, g_BreakoutTime, TimeCurrent());
    if(barsSinceBreakout < InpRetestMinBars) return -1;

    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double tolerance = InpRetestTolerance * g_PipValue;

    if(g_RetestDirection == ORDER_TYPE_BUY)
    {
        double prevLow1 = iLow(Symbol(), PERIOD_M15, 1);
        double prevLow2 = iLow(Symbol(), PERIOD_M15, 2);

        bool touchedZone = (prevLow1 <= g_RetestLevel + tolerance) ||
                           (prevLow2 <= g_RetestLevel + tolerance);
        bool priceAbove = bid > g_RetestLevel;

        if(touchedZone && priceAbove) return ORDER_TYPE_BUY;
    }
    else if(g_RetestDirection == ORDER_TYPE_SELL)
    {
        double prevHigh1 = iHigh(Symbol(), PERIOD_M15, 1);
        double prevHigh2 = iHigh(Symbol(), PERIOD_M15, 2);

        bool touchedZone = (prevHigh1 >= g_RetestLevel - tolerance) ||
                           (prevHigh2 >= g_RetestLevel - tolerance);
        bool priceBelow = bid < g_RetestLevel;

        if(touchedZone && priceBelow) return ORDER_TYPE_SELL;
    }

    return -1;
}

//+------------------------------------------------------------------+
//| SIGNAL 4: RSI MOMENTUM CONFIRMATION (Quant Fund Signal)            |
//| Returns: ORDER_TYPE_BUY if RSI > 50, ORDER_TYPE_SELL if RSI < 50   |
//| Used by institutional quant funds for momentum confirmation        |
//| Win rate documented: 55-73% when combined with other signals       |
//+------------------------------------------------------------------+
int IsRSIMomentumConfirmation()
{
    if(!InpUseRSIMomentum) return -1;

    double rsi[];
    ArraySetAsSeries(rsi, true);

    if(CopyBuffer(g_RSIHandle, 0, 0, 1, rsi) < 1) return -1;

    double currentRSI = rsi[0];

    // RSI > 50 = bullish momentum = confirms BUY
    if(currentRSI > 50)
    {
        return ORDER_TYPE_BUY;
    }
    // RSI < 50 = bearish momentum = confirms SELL
    else if(currentRSI < 50)
    {
        return ORDER_TYPE_SELL;
    }

    return -1;
}

//+------------------------------------------------------------------+
//| SIGNAL 5: ATR EXPANSION CONFIRMATION (Volatility Signal)           |
//| Returns: ORDER_TYPE_BUY/SELL if ATR > average * multiplier         |
//| High volatility = real breakout, low volatility = potential fakeout|
//| Used by hedge funds to validate breakout quality                   |
//+------------------------------------------------------------------+
int IsATRExpansionConfirmation(ENUM_ORDER_TYPE directionHint)
{
    if(!InpUseATRExpansion) return -1;

    double atr[];
    ArraySetAsSeries(atr, true);

    // Get ATR values for comparison
    int barsNeeded = InpATRAvgPeriod + 1;
    if(CopyBuffer(g_ATRExpHandle, 0, 0, barsNeeded, atr) < barsNeeded) return -1;

    double currentATR = atr[0];

    // Calculate average ATR over past periods
    double avgATR = 0;
    for(int i = 1; i <= InpATRAvgPeriod; i++)
    {
        avgATR += atr[i];
    }
    avgATR /= InpATRAvgPeriod;

    double threshold = avgATR * InpATRExpMultiplier;

    // ATR must be above threshold (volatility expansion)
    if(currentATR >= threshold)
    {
        // Return the direction hint (we just confirm volatility is sufficient)
        // ATR doesn't give direction, so we use the hint from other signals
        return (int)directionHint;
    }

    return -1;
}

//+------------------------------------------------------------------+
//| UNIFIED SIGNAL VOTING SYSTEM                                       |
//| Checks all signals and executes if enough signals agree            |
//+------------------------------------------------------------------+
void CheckSignalsAndExecute()
{
    // Count votes for each direction
    int buyVotes = 0;
    int sellVotes = 0;
    int activeSignals = 0;
    string triggeredSignals = "";

    // Check BREAKOUT signal (TRIGGER)
    if(InpUseBreakoutSignal)
    {
        activeSignals++;
        int breakoutDir = IsBreakoutSignal();
        if(breakoutDir == ORDER_TYPE_BUY) { buyVotes++; triggeredSignals += "BREAKOUT_BUY "; }
        else if(breakoutDir == ORDER_TYPE_SELL) { sellVotes++; triggeredSignals += "BREAKOUT_SELL "; }
    }

    // Check EMA TREND confirmation (CONFIRMATION - always active if enabled)
    if(InpUseEMACrossSignal)
    {
        activeSignals++;
        int emaTrendDir = IsEMATrendConfirmation();
        if(emaTrendDir == ORDER_TYPE_BUY) { buyVotes++; triggeredSignals += "EMA_TREND_BULL "; }
        else if(emaTrendDir == ORDER_TYPE_SELL) { sellVotes++; triggeredSignals += "EMA_TREND_BEAR "; }
    }

    // Check RETEST signal (TRIGGER - only if we have a pending retest)
    if(InpUseRetestEntry && g_RetestPending)
    {
        activeSignals++;
        int retestDir = IsRetestSignal();
        if(retestDir == ORDER_TYPE_BUY) { buyVotes++; triggeredSignals += "RETEST_BUY "; }
        else if(retestDir == ORDER_TYPE_SELL) { sellVotes++; triggeredSignals += "RETEST_SELL "; }
    }

    // Check RSI MOMENTUM confirmation (CONFIRMATION - Quant Fund Signal)
    if(InpUseRSIMomentum)
    {
        activeSignals++;
        int rsiDir = IsRSIMomentumConfirmation();
        if(rsiDir == ORDER_TYPE_BUY) { buyVotes++; triggeredSignals += "RSI_BULL "; }
        else if(rsiDir == ORDER_TYPE_SELL) { sellVotes++; triggeredSignals += "RSI_BEAR "; }
    }

    // Check ATR EXPANSION confirmation (CONFIRMATION - Volatility Signal)
    // ATR doesn't give direction, so we check based on current vote direction
    if(InpUseATRExpansion)
    {
        activeSignals++;
        // Determine which direction to hint based on current votes
        ENUM_ORDER_TYPE dirHint = (buyVotes >= sellVotes) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
        int atrDir = IsATRExpansionConfirmation(dirHint);
        if(atrDir == ORDER_TYPE_BUY) { buyVotes++; triggeredSignals += "ATR_EXP_BULL "; }
        else if(atrDir == ORDER_TYPE_SELL) { sellVotes++; triggeredSignals += "ATR_EXP_BEAR "; }
    }

    // No signals triggered
    if(buyVotes == 0 && sellVotes == 0) return;

    // Determine direction based on majority vote
    ENUM_ORDER_TYPE direction;
    int maxVotes;

    if(buyVotes >= sellVotes)
    {
        direction = ORDER_TYPE_BUY;
        maxVotes = buyVotes;
    }
    else
    {
        direction = ORDER_TYPE_SELL;
        maxVotes = sellVotes;
    }

    // Check if enough signals agree
    Print("════════════════════════════════════════");
    Print("VOTE SIGNAUX: BUY=", buyVotes, " SELL=", sellVotes, " (minimum requis: ", InpMinSignalsRequired, ")");
    Print("Signaux: ", triggeredSignals);

    if(maxVotes < InpMinSignalsRequired)
    {
        Print("BLOCKED: Pas assez de signaux (", maxVotes, " < ", InpMinSignalsRequired, ")");
        return;
    }

    Print("SIGNAL OK: ", maxVotes, " signaux ", direction == ORDER_TYPE_BUY ? "BUY" : "SELL");

    // Execute the trade with unified filter voting
    ExecuteUnifiedTrade(direction, triggeredSignals);
}

//+------------------------------------------------------------------+
//| Execute trade after signal and filter voting                       |
//+------------------------------------------------------------------+
void ExecuteUnifiedTrade(ENUM_ORDER_TYPE orderType, string signalNames)
{
    // Check filters with voting system
    if(!CheckFiltersWithVoting(orderType, "UNIFIED"))
    {
        return;
    }

    // Pre-trade margin check
    if(!CheckMarginForTrade())
    {
        Print("Insufficient margin");
        return;
    }

    double entryPrice, slPrice, tpPrice;
    double slDistance;

    if(orderType == ORDER_TYPE_BUY)
    {
        entryPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

        if(InpUseFixedSL)
        {
            slDistance = InpFixedSLPips * g_PipValue;
            slPrice = entryPrice - slDistance;
        }
        else
        {
            slPrice = g_AsianLow - (InpBreakoutBuffer * g_PipValue);
            slDistance = entryPrice - slPrice;
        }
        tpPrice = entryPrice + (slDistance * InpRiskReward);
    }
    else
    {
        entryPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);

        if(InpUseFixedSL)
        {
            slDistance = InpFixedSLPips * g_PipValue;
            slPrice = entryPrice + slDistance;
        }
        else
        {
            slPrice = g_AsianHigh + (InpBreakoutBuffer * g_PipValue);
            slDistance = slPrice - entryPrice;
        }
        tpPrice = entryPrice - (slDistance * InpRiskReward);
    }

    // Validate SL distance
    if(slDistance <= 0 || slDistance / g_PipValue > 150)
    {
        Print("Invalid SL distance");
        return;
    }

    double lotSize = CalculateLotSize(slDistance);
    if(lotSize <= 0) return;

    // Normalize prices
    slPrice = NormalizeDouble(slPrice, _Digits);
    tpPrice = NormalizeDouble(tpPrice, _Digits);
    entryPrice = NormalizeDouble(entryPrice, _Digits);

    string comment = StringFormat("Poutine_UNIFIED_%s_R%.1f",
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
        g_BreakoutTriggered = true;

        // Update EMA cross time to avoid re-entry
        if(StringFind(signalNames, "EMA_CROSS") >= 0)
        {
            g_LastEMACrossTime = iTime(Symbol(), PERIOD_H1, 1);
        }

        // Mark retest as triggered if used
        if(StringFind(signalNames, "RETEST") >= 0)
        {
            g_RetestTriggered = true;
            g_RetestPending = false;
        }

        // Setup retest if breakout was part of signal
        if(StringFind(signalNames, "BREAKOUT") >= 0 && InpUseRetestEntry && !g_RetestTriggered)
        {
            g_RetestPending = true;
            g_RetestDirection = orderType;
            g_RetestLevel = (orderType == ORDER_TYPE_BUY) ? g_AsianHigh : g_AsianLow;
            g_BreakoutTime = TimeCurrent();
        }

        g_OriginalRiskDistance = slDistance;
        g_OriginalEntryPrice = entryPrice;
        g_BEActivated = false;

        Print("════════ UNIFIED TRADE EXECUTED ════════");
        Print("Signaux: ", signalNames);
        Print("Direction: ", orderType == ORDER_TYPE_BUY ? "BUY" : "SELL");
        Print("Entry: ", DoubleToString(entryPrice, _Digits));
        Print("SL: ", DoubleToString(slPrice, _Digits), " (", DoubleToString(slDistance / g_PipValue, 1), " pips)");
        Print("TP: ", DoubleToString(tpPrice, _Digits));
        Print("Lot: ", DoubleToString(lotSize, 2));
        Print("═══════════════════════════════════════");
    }
    else
    {
        Print("Order failed: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| UNIFIED FILTER VOTING SYSTEM                                       |
//| Checks all filters and returns true if enough filters pass         |
//| Used by ALL signals (Breakout, EMA Cross, Retest)                  |
//+------------------------------------------------------------------+
bool CheckFiltersWithVoting(ENUM_ORDER_TYPE orderType, string signalName)
{
    // Check spread first (always required, not part of voting)
    double spreadPips = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * _Point / g_PipValue;
    if(spreadPips > InpMaxSpreadPips)
    {
        Print("SPREAD FILTER: Blocked - ", DoubleToString(spreadPips, 1), " > ", InpMaxSpreadPips, " pips");
        return false;
    }

    // Count active filters and passed filters
    int activeFilters = 0;
    int passedFilters = 0;

    // FILTER 1: SMMA 100 H1 Trend
    if(InpUseTrendFilter)
    {
        activeFilters++;
        if(CheckTrendFilter(orderType)) passedFilters++;
    }

    // FILTER 2: ADX Trend Strength
    if(InpUseADXFilter)
    {
        activeFilters++;
        if(CheckADXFilter(orderType)) passedFilters++;
    }

    // FILTER 3: Volume
    if(InpUseVolumeFilter)
    {
        activeFilters++;
        if(CheckVolumeFilter()) passedFilters++;
    }

    // FILTER 4: EMA 50 D1 (Higher Timeframe Trend)
    if(InpUseEMA50D1Filter)
    {
        activeFilters++;
        if(CheckEMA50D1Filter(orderType)) passedFilters++;
    }

    // Display vote result
    Print("[", signalName, "] VOTE FILTRES: ", passedFilters, "/", activeFilters, " (minimum requis: ", InpMinFiltersRequired, ")");

    // Check if enough filters passed
    if(passedFilters < InpMinFiltersRequired)
    {
        Print("[", signalName, "] BLOCKED: Pas assez de filtres validés (", passedFilters, " < ", InpMinFiltersRequired, ")");
        return false;
    }

    Print("[", signalName, "] FILTERS OK: ", passedFilters, "/", activeFilters, " validés");
    return true;
}

//+------------------------------------------------------------------+
//| Check SMMA 50 H1 Trend Filter                                     |
//+------------------------------------------------------------------+
bool CheckTrendFilter(ENUM_ORDER_TYPE orderType)
{
    if(!InpUseTrendFilter) return true;  // Filter disabled

    double smma[];
    ArraySetAsSeries(smma, true);

    if(CopyBuffer(g_SMMAHandle, 0, 0, 1, smma) <= 0)
    {
        Print("Failed to get SMMA value");
        return true;  // Allow trade if indicator fails
    }

    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);

    // BUY only if price > SMMA 100 (uptrend)
    if(orderType == ORDER_TYPE_BUY)
    {
        if(currentPrice > smma[0])
        {
            Print("TREND OK: Price ", DoubleToString(currentPrice, _Digits),
                  " > SMMA100 ", DoubleToString(smma[0], _Digits), " = UPTREND");
            return true;
        }
        else
        {
            Print("TREND FILTER: BUY blocked - Price below SMMA 100 H1");
            return false;
        }
    }
    // SELL only if price < SMMA 100 (downtrend)
    else
    {
        if(currentPrice < smma[0])
        {
            Print("TREND OK: Price ", DoubleToString(currentPrice, _Digits),
                  " < SMMA100 ", DoubleToString(smma[0], _Digits), " = DOWNTREND");
            return true;
        }
        else
        {
            Print("TREND FILTER: SELL blocked - Price above SMMA 100 H1");
            return false;
        }
    }
}

//+------------------------------------------------------------------+
//| Check SMMA Slope Filter                                           |
//| Rule: SMMA must have a minimum slope (strong trend direction)     |
//| Flat MA = ranging market = poor breakout trades                   |
//+------------------------------------------------------------------+
bool CheckSlopeFilter(ENUM_ORDER_TYPE orderType)
{
    if(!InpUseSlopeFilter) return true;  // Filter disabled

    double smma[];
    ArraySetAsSeries(smma, true);

    // Get SMMA values for slope calculation
    int barsNeeded = InpSlopeLookback + 1;
    if(CopyBuffer(g_SMMAHandle, 0, 0, barsNeeded, smma) < barsNeeded)
    {
        Print("Failed to get SMMA values for slope");
        return true;  // Allow trade if indicator fails
    }

    // Calculate slope: difference between current SMMA and SMMA X bars ago
    double currentSMMA = smma[0];
    double oldSMMA = smma[InpSlopeLookback];
    double slopePips = (currentSMMA - oldSMMA) / g_PipValue;
    double absSlope = MathAbs(slopePips);

    // Check if slope is strong enough
    if(absSlope < InpMinSlopePips)
    {
        Print("SLOPE FILTER: Blocked - SMMA slope ", DoubleToString(slopePips, 1), " pips < ", InpMinSlopePips, " (flat MA = ranging)");
        return false;
    }

    // Check if slope direction matches trade direction
    if(orderType == ORDER_TYPE_BUY && slopePips < 0)
    {
        Print("SLOPE FILTER: BUY blocked - SMMA slope is NEGATIVE (", DoubleToString(slopePips, 1), " pips) = downtrend");
        return false;
    }
    if(orderType == ORDER_TYPE_SELL && slopePips > 0)
    {
        Print("SLOPE FILTER: SELL blocked - SMMA slope is POSITIVE (", DoubleToString(slopePips, 1), " pips) = uptrend");
        return false;
    }

    Print("SLOPE OK: SMMA moved ", DoubleToString(slopePips, 1), " pips in ", InpSlopeLookback, " bars (strong ", slopePips > 0 ? "UP" : "DOWN", "trend)");
    return true;
}

//+------------------------------------------------------------------+
//| Check Price Distance from MA Filter                               |
//| Rule: Price must be at minimum distance from SMMA                 |
//| Price too close to MA = choppy/ranging, poor breakout quality     |
//+------------------------------------------------------------------+
bool CheckDistanceFilter(ENUM_ORDER_TYPE orderType)
{
    if(!InpUseDistanceFilter) return true;  // Filter disabled

    double smma[];
    ArraySetAsSeries(smma, true);

    if(CopyBuffer(g_SMMAHandle, 0, 0, 1, smma) <= 0)
    {
        Print("Failed to get SMMA value for distance");
        return true;  // Allow trade if indicator fails
    }

    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double distancePips = MathAbs(currentPrice - smma[0]) / g_PipValue;

    // Check if price is far enough from MA
    if(distancePips < InpMinDistancePips)
    {
        Print("DISTANCE FILTER: Blocked - Price only ", DoubleToString(distancePips, 1), " pips from SMMA (< ", InpMinDistancePips, " = too close, ranging)");
        return false;
    }

    // Verify price is on correct side of MA for trade direction
    if(orderType == ORDER_TYPE_BUY && currentPrice < smma[0])
    {
        Print("DISTANCE FILTER: BUY blocked - Price below SMMA");
        return false;
    }
    if(orderType == ORDER_TYPE_SELL && currentPrice > smma[0])
    {
        Print("DISTANCE FILTER: SELL blocked - Price above SMMA");
        return false;
    }

    Print("DISTANCE OK: Price ", DoubleToString(distancePips, 1), " pips ", currentPrice > smma[0] ? "ABOVE" : "BELOW", " SMMA (clear trend separation)");
    return true;
}

//+------------------------------------------------------------------+
//| Check ADX Trend Strength Filter (IMPROVED v2)                      |
//| Rule 1: ADX > 25 = Strong trend                                   |
//| Rule 2: ADX rising = Trend strengthening (ADX > ADX[1])           |
//| Rule 3: DI Direction = BUY needs DI+>DI-, SELL needs DI->DI+      |
//+------------------------------------------------------------------+
bool CheckADXFilter(ENUM_ORDER_TYPE orderType)
{
    if(!InpUseADXFilter) return true;  // Filter disabled

    double adx[], diPlus[], diMinus[];
    ArraySetAsSeries(adx, true);
    ArraySetAsSeries(diPlus, true);
    ArraySetAsSeries(diMinus, true);

    // Buffer 0 = ADX, Buffer 1 = DI+, Buffer 2 = DI-
    if(CopyBuffer(g_ADXHandle, 0, 0, 2, adx) <= 0)
    {
        Print("Failed to get ADX values");
        return true;
    }
    if(CopyBuffer(g_ADXHandle, 1, 0, 1, diPlus) <= 0)
    {
        Print("Failed to get DI+ values");
        return true;
    }
    if(CopyBuffer(g_ADXHandle, 2, 0, 1, diMinus) <= 0)
    {
        Print("Failed to get DI- values");
        return true;
    }

    double currentADX = adx[0];
    double previousADX = adx[1];
    double currentDIPlus = diPlus[0];
    double currentDIMinus = diMinus[0];

    // Rule 1: ADX must be > minimum level (strong trend)
    if(currentADX < InpADXMinLevel)
    {
        Print("ADX FILTER: Blocked - ADX ", DoubleToString(currentADX, 1), " < ", InpADXMinLevel, " (weak trend)");
        return false;
    }

    // Rule 2: ADX must be rising (trend strengthening)
    if(InpADXRising && currentADX <= previousADX)
    {
        Print("ADX FILTER: Blocked - ADX declining (", DoubleToString(currentADX, 1), " <= ", DoubleToString(previousADX, 1), ")");
        return false;
    }

    // Rule 3: DI Direction must match trade direction
    if(InpUseDIDirection)
    {
        if(orderType == ORDER_TYPE_BUY && currentDIPlus <= currentDIMinus)
        {
            Print("ADX FILTER: Blocked BUY - DI+ (", DoubleToString(currentDIPlus, 1), ") <= DI- (", DoubleToString(currentDIMinus, 1), ") = BEARISH");
            return false;
        }
        if(orderType == ORDER_TYPE_SELL && currentDIMinus <= currentDIPlus)
        {
            Print("ADX FILTER: Blocked SELL - DI- (", DoubleToString(currentDIMinus, 1), ") <= DI+ (", DoubleToString(currentDIPlus, 1), ") = BULLISH");
            return false;
        }
    }

    // All conditions passed
    Print("ADX OK: ", DoubleToString(currentADX, 1), " | DI+: ", DoubleToString(currentDIPlus, 1), " | DI-: ", DoubleToString(currentDIMinus, 1));
    if(InpADXRising)
        Print("ADX RISING: ", DoubleToString(previousADX, 1), " -> ", DoubleToString(currentADX, 1));
    if(InpUseDIDirection)
        Print("DI DIRECTION: ", orderType == ORDER_TYPE_BUY ? "DI+ > DI- = BULLISH OK" : "DI- > DI+ = BEARISH OK");

    return true;
}

//+------------------------------------------------------------------+
//| Check Volume Confirmation Filter (IMPROVED)                        |
//| Rule: Breakout candle volume must exceed 120% of average volume   |
//| High volume = Real breakout, Low volume = Fakeout                  |
//+------------------------------------------------------------------+
bool CheckVolumeFilter()
{
    if(!InpUseVolumeFilter) return true;  // Filter disabled

    // Get PREVIOUS candle volume (completed candle, not current)
    long breakoutVolume = iVolume(Symbol(), PERIOD_M15, 1);

    // Calculate average volume over past periods (starting from candle 2)
    double avgVolume = 0;
    for(int i = 2; i <= InpVolumePeriod + 1; i++)
    {
        avgVolume += (double)iVolume(Symbol(), PERIOD_M15, i);
    }
    avgVolume /= InpVolumePeriod;

    double threshold = avgVolume * InpVolumeMultiplier;
    double volumeRatio = (avgVolume > 0) ? (breakoutVolume / avgVolume) * 100 : 0;

    // Breakout candle volume must exceed threshold (default 120%)
    if(breakoutVolume >= threshold)
    {
        Print("VOLUME OK: ", breakoutVolume, " = ", DoubleToString(volumeRatio, 0), "% of avg (threshold: ", DoubleToString(InpVolumeMultiplier * 100, 0), "%)");
        Print("HIGH VOLUME BREAKOUT = REAL MOMENTUM");
        return true;
    }
    else
    {
        Print("VOLUME FILTER: Blocked - ", breakoutVolume, " = ", DoubleToString(volumeRatio, 0), "% of avg < ", DoubleToString(InpVolumeMultiplier * 100, 0), "% threshold");
        Print("LOW VOLUME = POTENTIAL FAKEOUT");
        return false;
    }
}

//+------------------------------------------------------------------+
//| Check EMA 50 Daily Filter (Higher Timeframe Trend)                |
//| Rule: Trade only in direction of Daily trend                      |
//| BUY only if Price > EMA50 D1 (Daily uptrend)                      |
//| SELL only if Price < EMA50 D1 (Daily downtrend)                   |
//+------------------------------------------------------------------+
bool CheckEMA50D1Filter(ENUM_ORDER_TYPE orderType)
{
    if(!InpUseEMA50D1Filter) return true;  // Filter disabled

    double ema50d1[];
    ArraySetAsSeries(ema50d1, true);

    if(CopyBuffer(g_EMA50D1Handle, 0, 0, 1, ema50d1) <= 0)
    {
        Print("Failed to get EMA 50 D1 value");
        return true;  // Allow trade if indicator fails
    }

    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);

    // BUY only if price > EMA 50 D1 (Daily uptrend)
    if(orderType == ORDER_TYPE_BUY)
    {
        if(currentPrice > ema50d1[0])
        {
            Print("EMA50 D1 OK: Price ", DoubleToString(currentPrice, _Digits),
                  " > EMA50 D1 ", DoubleToString(ema50d1[0], _Digits), " = DAILY UPTREND");
            return true;
        }
        else
        {
            Print("EMA50 D1 FILTER: BUY blocked - Price below EMA 50 D1 (Daily downtrend)");
            return false;
        }
    }
    // SELL only if price < EMA 50 D1 (Daily downtrend)
    else
    {
        if(currentPrice < ema50d1[0])
        {
            Print("EMA50 D1 OK: Price ", DoubleToString(currentPrice, _Digits),
                  " < EMA50 D1 ", DoubleToString(ema50d1[0], _Digits), " = DAILY DOWNTREND");
            return true;
        }
        else
        {
            Print("EMA50 D1 FILTER: SELL blocked - Price above EMA 50 D1 (Daily uptrend)");
            return false;
        }
    }
}

//+------------------------------------------------------------------+
//| Execute Breakout Trade                                            |
//+------------------------------------------------------------------+
void ExecuteBreakoutTrade(ENUM_ORDER_TYPE orderType)
{
    // Use unified filter voting system
    if(!CheckFiltersWithVoting(orderType, "BREAKOUT"))
    {
        return;
    }

    // Pre-trade margin check
    if(!CheckMarginForTrade())
    {
        Print("Insufficient margin");
        return;
    }

    double entryPrice, slPrice, tpPrice;
    double slDistance;

    if(orderType == ORDER_TYPE_BUY)
    {
        entryPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

        // SL Placement: Fixed OR Box Opposite
        if(InpUseFixedSL)
        {
            // Fixed SL = faster TP (e.g., 25 pips SL = 75 pips TP avec R:R 3.0)
            slDistance = InpFixedSLPips * g_PipValue;
            slPrice = entryPrice - slDistance;
            Print("FIXED SL: ", InpFixedSLPips, " pips below entry");
        }
        else
        {
            // Original: SL at opposite side of box (Asian Low - buffer)
            slPrice = g_AsianLow - (InpBreakoutBuffer * g_PipValue);
            slDistance = entryPrice - slPrice;
        }
        // TP at R:R ratio
        tpPrice = entryPrice + (slDistance * InpRiskReward);
    }
    else
    {
        entryPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);

        // SL Placement: Fixed OR Box Opposite
        if(InpUseFixedSL)
        {
            // Fixed SL = faster TP
            slDistance = InpFixedSLPips * g_PipValue;
            slPrice = entryPrice + slDistance;
            Print("FIXED SL: ", InpFixedSLPips, " pips above entry");
        }
        else
        {
            // Original: SL at opposite side of box (Asian High + buffer)
            slPrice = g_AsianHigh + (InpBreakoutBuffer * g_PipValue);
            slDistance = slPrice - entryPrice;
        }
        // TP at R:R ratio
        tpPrice = entryPrice - (slDistance * InpRiskReward);
    }

    // Validate SL distance
    if(slDistance <= 0 || slDistance / g_PipValue > 150)
    {
        Print("Invalid SL distance: ", DoubleToString(slDistance / g_PipValue, 1), " pips");
        return;
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

    string comment = StringFormat("Poutine_GU_%s_R%.1f",
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
        g_BreakoutTriggered = true;

        // Store original risk for BE calculations
        g_OriginalRiskDistance = slDistance;
        g_OriginalEntryPrice = entryPrice;
        g_BEActivated = false;

        Print("═══════════════════════════════════════");
        Print("LONDON BREAKOUT GBPUSD ", orderType == ORDER_TYPE_BUY ? "BUY" : "SELL");
        Print("Asian Range: ", DoubleToString(g_AsianLow, _Digits), " - ", DoubleToString(g_AsianHigh, _Digits));
        Print("Box Size: ", DoubleToString(g_BoxSize, 1), " pips");
        Print("Entry: ", DoubleToString(entryPrice, _Digits));
        Print("SL: ", DoubleToString(slPrice, _Digits), " (", DoubleToString(slDistance / g_PipValue, 1), " pips)");
        Print("TP: ", DoubleToString(tpPrice, _Digits), " (R:", InpRiskReward, " = ", DoubleToString(slDistance * InpRiskReward / g_PipValue, 1), " pips)");
        Print("Lot: ", DoubleToString(lotSize, 2), " | Risk: ", InpRiskPercent, "%");
        Print("═══════════════════════════════════════");

        // Setup Retest Entry (2ème entrée professionnelle)
        if(InpUseRetestEntry && !g_RetestTriggered)
        {
            g_RetestPending = true;
            g_RetestDirection = orderType;
            g_RetestLevel = (orderType == ORDER_TYPE_BUY) ? g_AsianHigh : g_AsianLow;
            g_BreakoutTime = TimeCurrent();
            Print("RETEST SETUP: En attente de pullback vers ", DoubleToString(g_RetestLevel, _Digits));
        }
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

    // FTMO Mode: Use initial balance (no compounding)
    // Normal Mode: Use current balance (compounding)
    double balance = InpUseFTMOLotCalc ? g_InitialBalance : accInfo.Balance();
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
//| Manage Open Positions (Break-Even, Trailing)                      |
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

        // === MAX LOSS PROTECTION (Priority #1) ===
        // Close immediately if unrealized loss exceeds threshold ($ OR pips)
        double positionProfit = PositionGetDouble(POSITION_PROFIT);
        double positionSwap = PositionGetDouble(POSITION_SWAP);
        double totalPL = positionProfit + positionSwap;

        // Calculate current loss in pips
        double currentPriceLoss = 0;
        if(posType == POSITION_TYPE_BUY)
            currentPriceLoss = (openPrice - bid) / g_PipValue;  // Positive = loss for BUY
        else
            currentPriceLoss = (ask - openPrice) / g_PipValue;  // Positive = loss for SELL

        if(InpUseMaxLossProtection)
        {
            // Protection 1: Dollar-based
            if(totalPL <= -InpMaxLossPerTrade)
            {
                Print("═══════════════════════════════════════");
                Print("MAX LOSS $ PROTECTION TRIGGERED!");
                Print("Position Loss: $", DoubleToString(totalPL, 2), " <= Max: -$", DoubleToString(InpMaxLossPerTrade, 2));
                Print("EMERGENCY CLOSE to prevent further loss");

                if(trade.PositionClose(ticket))
                {
                    Print("Position closed - Loss capped at $", DoubleToString(MathAbs(totalPL), 2));
                }
                Print("═══════════════════════════════════════");
                continue;  // Move to next position
            }

            // Protection 2: Pips-based (BACKUP - catches cases where $ calc fails)
            if(currentPriceLoss >= InpMaxLossPips)
            {
                Print("═══════════════════════════════════════");
                Print("MAX LOSS PIPS PROTECTION TRIGGERED!");
                Print("Position Loss: ", DoubleToString(currentPriceLoss, 1), " pips >= Max: ", InpMaxLossPips, " pips");
                Print("BACKUP PROTECTION - EMERGENCY CLOSE");

                if(trade.PositionClose(ticket))
                {
                    Print("Position closed at ", DoubleToString(currentPriceLoss, 1), " pips loss ($", DoubleToString(MathAbs(totalPL), 2), ")");
                }
                Print("═══════════════════════════════════════");
                continue;  // Move to next position
            }
        }

        // === MAX PROFIT PROTECTION (Priority #2) ===
        // Lock in profits when target reached - Don't let winners become losers!
        if(InpUseMaxProfitProtection)
        {
            if(totalPL >= InpMaxProfitPerTrade)
            {
                Print("═══════════════════════════════════════");
                Print("MAX PROFIT PROTECTION TRIGGERED!");
                Print("Position Profit: +$", DoubleToString(totalPL, 2), " >= Target: +$", DoubleToString(InpMaxProfitPerTrade, 2));
                Print("LOCKING IN 3R PROFIT!");

                if(trade.PositionClose(ticket))
                {
                    Print("Position closed - Profit locked at +$", DoubleToString(totalPL, 2));
                }
                Print("═══════════════════════════════════════");
                continue;  // Move to next position
            }
        }

        // Use ORIGINAL risk distance (stored when trade opened, not recalculated!)
        double riskDistance = g_OriginalRiskDistance;
        if(riskDistance <= 0) riskDistance = MathAbs(openPrice - currentSL);  // Fallback

        double newSL = 0;

        // === BREAK-EVEN LOGIC ===
        if(InpUseBreakEven && !g_BEActivated)
        {
            double beDistance = riskDistance * InpBreakEvenTrigger;

            if(posType == POSITION_TYPE_BUY)
            {
                if(bid >= openPrice + beDistance && currentSL < openPrice)
                {
                    newSL = NormalizeDouble(openPrice + (2 * _Point), _Digits);
                    g_BEActivated = true;
                    Print("═══ BREAK-EVEN ACTIVATED ═══");
                    Print("Trigger: +", InpBreakEvenTrigger, "R (", DoubleToString(beDistance / g_PipValue, 1), " pips)");
                    Print("New SL: ", DoubleToString(newSL, _Digits), " (entry + 2 points)");
                }
            }
            else // SELL
            {
                if(ask <= openPrice - beDistance && currentSL > openPrice)
                {
                    newSL = NormalizeDouble(openPrice - (2 * _Point), _Digits);
                    g_BEActivated = true;
                    Print("═══ BREAK-EVEN ACTIVATED ═══");
                    Print("Trigger: +", InpBreakEvenTrigger, "R (", DoubleToString(beDistance / g_PipValue, 1), " pips)");
                    Print("New SL: ", DoubleToString(newSL, _Digits), " (entry - 2 points)");
                }
            }
        }

        // === TRAILING STOP (only if enabled and after BE) ===
        if(InpUseTrailingStop)
        {
            bool afterBE = (posType == POSITION_TYPE_BUY && currentSL >= openPrice) ||
                           (posType == POSITION_TYPE_SELL && currentSL <= openPrice);

            if(afterBE)
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
        g_BoxReady = false;
        g_BreakoutTriggered = false;
        g_AsianHigh = 0;
        g_AsianLow = 999999;
        g_BoxDate = today;

        // Reset BE tracking for new day
        g_OriginalRiskDistance = 0;
        g_OriginalEntryPrice = 0;
        g_BEActivated = false;

        // Reset Retest tracking for new day
        g_RetestPending = false;
        g_RetestTriggered = false;
        g_RetestLevel = 0;
        g_BreakoutTime = 0;

        Print("═══════════════════════════════════════");
        Print("NEW TRADING DAY - LONDON BREAKOUT GBPUSD");
        Print("Balance: $", DoubleToString(g_DailyStartBalance, 2));
        Print("═══════════════════════════════════════");
    }
}

//+------------------------------------------------------------------+
//| Calculate Broker GMT Offset                                       |
//| Auto-detect in LIVE mode, Manual in BACKTEST                      |
//+------------------------------------------------------------------+
int CalculateBrokerGMTOffset()
{
    // In backtest: always use manual setting
    if(MQLInfoInteger(MQL_TESTER))
    {
        Print("BACKTEST MODE: Using manual GMT offset = ", InpBrokerGMTOffset);
        return InpBrokerGMTOffset;
    }

    // In live: auto-detect if enabled
    if(InpAutoDetectGMT)
    {
        datetime brokerTime = TimeCurrent();
        datetime gmtTime = TimeGMT();

        if(gmtTime == 0)
        {
            Print("GMT AUTO-DETECT FAILED: Using manual offset = ", InpBrokerGMTOffset);
            return InpBrokerGMTOffset;
        }

        int offset = (int)((brokerTime - gmtTime) / 3600);

        // Sanity check
        if(offset < -12) offset = -12;
        if(offset > 14) offset = 14;

        Print("GMT AUTO-DETECTED: Broker GMT+", offset, " (Server: ", TimeToString(brokerTime), " | GMT: ", TimeToString(gmtTime), ")");
        return offset;
    }
    else
    {
        Print("GMT MANUAL MODE: Using offset = ", InpBrokerGMTOffset);
        return InpBrokerGMTOffset;
    }
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
void UpdatePanel()
{
    int gmtHour, gmtMinute;
    GetGMTTime(gmtHour, gmtMinute);

    double equity = accInfo.Equity();
    double dailyPL = equity - g_DailyStartBalance;

    string info = "\n";
    info += "════════════════════════════════════════\n";
    info += "   POUTINE EA v11.0 - LONDON BREAKOUT\n";
    info += "   GBPUSD | Best Pair for London BO\n";
    info += "════════════════════════════════════════\n";
    info += " Status: " + g_Status + "\n";
    info += " GMT: " + IntegerToString(gmtHour) + ":" + (gmtMinute < 10 ? "0" : "") + IntegerToString(gmtMinute) + "\n";
    info += "────────────────────────────────────────\n";
    info += " ASIAN BOX (00-06 GMT):\n";
    info += "   High: " + DoubleToString(g_AsianHigh, _Digits) + "\n";
    info += "   Low:  " + DoubleToString(g_AsianLow, _Digits) + "\n";
    info += "   Size: " + DoubleToString(g_BoxSize, 1) + " pips";
    if(g_BoxSize < InpMinBoxSize) info += " (TOO SMALL)";
    else if(g_BoxSize > InpMaxBoxSize) info += " (TOO LARGE)";
    else info += " (OK)";
    info += "\n";
    info += "   Ready: " + (g_BoxReady ? "YES" : "NO") + "\n";
    info += "────────────────────────────────────────\n";
    info += " R:R = 1:" + DoubleToString(InpRiskReward, 1) + " | WR Target: 55%+\n";
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
    Print("═══════════════════════════════════════════════════════════");
    Print("   POUTINE EA v11.0 - GBPUSD LONDON BREAKOUT");
    Print("   THE BEST PAIR FOR LONDON BREAKOUT STRATEGY");
    Print("═══════════════════════════════════════════════════════════");
    Print("WHY GBPUSD?");
    Print("  - GBP barely trades during Asian session = real levels");
    Print("  - 25% of all forex volume when London opens");
    Print("  - Most volatile at London Open");
    Print("  - 65-75% win rate documented on backtests");
    Print("═══════════════════════════════════════════════════════════");
    Print("TIMELINE (GMT):");
    Print("  00:00 - 06:00 | ASIAN RANGE (Build the Box)");
    Print("  07:00 - 10:00 | LONDON ENTRY (First 3 hours = strongest)");
    Print("  10:00 - 17:00 | TRADE MANAGEMENT");
    Print("  17:00         | FORCE CLOSE (Before US session ends)");
    Print("═══════════════════════════════════════════════════════════");
    Print("BREAKOUT SETTINGS (Optimized for GBPUSD):");
    Print("  Buffer: ", InpBreakoutBuffer, " pips (10 for GBP)");
    Print("  Min Box: ", InpMinBoxSize, " pips | Max Box: ", InpMaxBoxSize, " pips");
    Print("  Wait for Close: ", InpWaitForClose ? "YES (Safer)" : "NO (More signals)");
    Print("═══════════════════════════════════════════════════════════");
    Print("RISK MANAGEMENT:");
    Print("  Risk: ", InpRiskPercent, "% per trade");
    Print("  R:R Ratio: 1:", InpRiskReward, " (optimal for 55%+ WR)");
    Print("  Break-Even: ", InpUseBreakEven ? "ON at +" + DoubleToString(InpBreakEvenTrigger, 1) + "R" : "OFF");
    Print("  Max Spread: ", InpMaxSpreadPips, " pips");
    Print("═══════════════════════════════════════════════════════════");
    Print("Expected Performance:");
    Print("  Win Rate: 55-65% (vs 40-50% on EURUSD)");
    Print("  Expectancy: (0.55 x 1.5) - (0.45 x 1.0) = +0.375R/trade");
    Print("  Profit Factor: 1.5-2.0");
    Print("═══════════════════════════════════════════════════════════");
    Print("POUTINE GBPUSD v11.0 LONDON BREAKOUT INITIALIZED");
    Print("═══════════════════════════════════════════════════════════");
}
//+------------------------------------------------------------------+
