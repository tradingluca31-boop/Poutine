# POUTINE EA v2.0 - Institutional Grade

**Professional London Breakout Expert Advisor for XAUUSD (Gold)**

Based on the best practices from top-rated MQL5 EAs including The Gold Reaper, Gold Trade Pro, and institutional Smart Money Concepts.

## Strategy Overview

```
TIMELINE (GMT)
00:00 ──────── 07:00 ──────── 10:00 ──────── 22:00 ──────── 00:00
  │              │              │              │              │
  │    ASIAN     │   LONDON     │    TRADE     │   FORCE      │
  │    RANGE     │   ENTRY      │   MANAGEMENT │   CLOSE      │
  │   (Build     │   WINDOW     │              │   (Before    │
  │    the Box)  │   (Breakout) │   (Trailing) │    Asia)     │
```

## Key Features

### Institutional-Grade Risk Management
- **Dynamic Position Sizing**: Automatic lot calculation based on % risk
- **Pre-Trade Margin Check**: Validates sufficient margin before entry
- **FTMO Protection**: Built-in daily loss and total drawdown limits
- **Max Daily Loss**: Default 4% (FTMO limit: 5%)
- **Max Total DD**: Default 8% (FTMO limit: 10%)

### Smart Money Concepts
- **Liquidity Sweep Detection**: Identifies institutional stop hunts
- **False Breakout Filter**: Avoids retail traps at Asian range edges
- **Session-Based Logic**: Trades institutional flow at London open

### Professional Filters
- **Range Size Validation**: Filters micro and macro ranges
- **ATR Volatility Filter**: Ensures sufficient market movement
- **Spread Filter**: Avoids high-spread conditions
- **Single Trade Per Day**: Prevents overtrading

## How It Works

### Phase 1: Asian Range (00:00 - 07:00 GMT)
Records the High/Low of the quiet Asian session to create the "box".

### Phase 2: London Entry (07:00 - 10:00 GMT)
- Waits for M15 candle to CLOSE outside the Asian range (Safe mode)
- Checks for liquidity sweeps (Smart Money)
- Validates all filters before entry
- Executes trade with calculated position size

### Phase 3: Trade Management
- ATR-based Trailing Stop (locks profits dynamically)
- Continuous FTMO limit monitoring

### Phase 4: Force Close (22:00 GMT)
All positions closed before Asian session starts - no overnight exposure.

## Settings

### Risk Management
| Parameter | Default | Description |
|-----------|---------|-------------|
| RiskPercent | 1.0 | Risk per trade (%) |
| RiskReward | 3.0 | Risk:Reward ratio |
| MaxDailyLossPct | 4.0 | FTMO daily loss limit |
| MaxTotalDDPct | 8.0 | FTMO total drawdown limit |
| UseFTMOProtection | true | Enable FTMO protection |

### Trade Settings
| Parameter | Default | Description |
|-----------|---------|-------------|
| MagicNumber | 202401 | EA identifier |
| SLType | Aggressive | SL at middle of box |
| EntryType | Safe | Wait for candle close |
| UseTrailingStop | true | ATR-based trailing |
| TrailingATRMult | 1.5 | Trailing distance multiplier |

### Session Times (GMT)
| Parameter | Default | Description |
|-----------|---------|-------------|
| AsianStartHour | 0 | Asian range start |
| AsianEndHour | 7 | Asian range end |
| LondonStartHour | 7 | Entry window start |
| LondonEndHour | 10 | Entry window end |
| ForceCloseHour | 22 | Force close time |

### Breakout Filters
| Parameter | Default | Description |
|-----------|---------|-------------|
| ConfirmTF | M15 | Confirmation timeframe |
| MinRangePts | 300 | Minimum Asian range |
| MaxRangePts | 2500 | Maximum Asian range |
| BreakoutBuffer | 50 | Breakout confirmation buffer |
| MaxSpread | 40 | Maximum spread allowed |

### Smart Money Filters
| Parameter | Default | Description |
|-----------|---------|-------------|
| UseLiquiditySweep | true | Detect stop hunts |
| SweepBuffer | 100 | Sweep detection buffer |
| UseATRFilter | true | Volatility filter |
| ATRPeriod | 14 | ATR calculation period |

## Installation

1. Copy `Poutine.mq5` to `MQL5/Experts/` folder
2. Compile in MetaEditor (F7)
3. Attach to XAUUSD M15 chart
4. Enable AutoTrading
5. Recommended: Run on VPS 24/5

## Prop Firm Compatibility

Designed for FTMO and similar prop firms:
- Fixed Stop Loss on every trade
- No martingale or grid
- No high-risk strategies
- Daily and total drawdown protection
- Single position at a time

## Backtest Recommendations

- Symbol: XAUUSD
- Timeframe: M15
- Mode: Every tick based on real ticks
- Spread: Variable or fixed 25-30 points
- Initial deposit: $10,000+

## Disclaimer

Trading involves substantial risk. Past performance is not indicative of future results. Test on demo before live trading.

## License

MIT License - Free to use and modify

## Credits

Inspired by institutional trading concepts and best practices from:
- The Gold Reaper MT5
- Gold Trade Pro MT5
- Opening Range Breakout Master
- Smart Money Concepts (ICT)
