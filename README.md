# Poutine EA v12.0 - London Breakout GBPUSD

## Description
Expert Advisor professionnel pour le trading de la stratégie London Breakout sur GBPUSD.

## Caractéristiques

### Signaux d'Entrée (Système de Vote)
1. **Breakout Asian Range** - Cassure de la box asiatique
2. **EMA 20/55 Trend** - Confirmation de tendance H1
3. **Retest Entry** - Entrée sur pullback après breakout
4. **RSI Momentum** - RSI > 50 = BUY, RSI < 50 = SELL
5. **ATR Expansion** - Volatilité suffisante pour breakout

### Filtres (Système de Vote)
1. **SMMA 100 H1** - Filtre de tendance
2. **ADX** - Force de la tendance (> 25)
3. **Volume** - Volume > 120% moyenne
4. **EMA 50 D1** - Tendance Daily (Higher Timeframe)

### Gestion du Risque
- **Risk % configurable** (défaut: 1%)
- **Mode FTMO** - Lot calculé sur capital initial (pas de compounding)
- **Max Loss Protection** - Ferme si perte > $100
- **Max Profit Protection** - Ferme si gain > $300 (3R)
- **SL fixe** - 25 pips
- **R:R** - 3.0

### FTMO Compatible
- Max Daily Loss: 4%
- Force Close à 20h GMT
- Pas de trades overnight

## Installation
1. Copier `Poutine_v12.mq5` dans `MQL5/Experts/`
2. Compiler dans MetaEditor
3. Attacher au graphique GBPUSD H1

## Paramètres Recommandés
- Symbol: **GBPUSD**
- Timeframe: **H1**
- Risk: **0.5-1.0%**
- Broker GMT Offset: **Ajuster selon votre broker**

## Backtest Results (2024)
- Profit: ~$2,000+ sur $10,000
- Sharpe Ratio: ~3.0
- Max Drawdown: ~10%
- Win Rate: ~40%

## Auteur
Trading Luca

## License
Private - All Rights Reserved
