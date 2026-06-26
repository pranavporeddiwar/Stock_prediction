class PortfolioItem {
  final String symbol;
  final int quantity;
  final double averageBuyPrice;
  double currentLivePrice;

  PortfolioItem({
    required this.symbol,
    required this.quantity,
    required this.averageBuyPrice,
    this.currentLivePrice = 0.0,
  });

  double get totalInvestment => quantity * averageBuyPrice;
  double get currentValue => quantity * currentLivePrice;
  double get totalProfitLoss => currentValue - totalInvestment;
  double get profitLossPercentage =>
      totalInvestment > 0 ? (totalProfitLoss / totalInvestment) * 100 : 0.0;
}