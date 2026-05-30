enum MarketSide { yes, no }

class Market {
  const Market({
    required this.id,
    required this.question,
    required this.category,
    required this.context,
    required this.yesPrice,
    required this.noPrice,
    required this.volume,
    required this.liquidity,
    required this.deadline,
    required this.trend,
    required this.isFeatured,
    required this.tags,
    required this.history,
    required this.comments,
    required this.news,
    required this.slug,
    this.contractAddress,
    this.imageUrl = '',
    this.volume24hr = 0,
    this.lastTradePrice = 0,
    this.bestBid = 0,
    this.bestAsk = 0,
    this.spread = 0,
    this.clobTokenId = '',
    this.liquidityNum = 0,
    this.competitive = 0,
  });

  final String id;
  final String slug;
  final String? contractAddress;
  final String question;
  final String category;
  final String context;
  final double yesPrice;
  final double noPrice;
  final String volume;
  final String liquidity;
  final DateTime deadline;
  final double trend;
  final bool isFeatured;
  final List<String> tags;
  final List<double> history;
  final List<MarketComment> comments;
  final List<MarketNews> news;
  final String imageUrl;
  final double volume24hr;
  final double lastTradePrice;
  final double bestBid;
  final double bestAsk;
  final double spread;
  final String clobTokenId;
  final double liquidityNum;
  final double competitive;

  bool get trendIsPositive => trend >= 0;

  Market copyWith({String? contractAddress, String? slug}) => Market(
        id: id,
        slug: slug ?? this.slug,
        contractAddress: contractAddress ?? this.contractAddress,
        question: question,
        category: category,
        context: context,
        yesPrice: yesPrice,
        noPrice: noPrice,
        volume: volume,
        liquidity: liquidity,
        deadline: deadline,
        trend: trend,
        isFeatured: isFeatured,
        tags: tags,
        history: history,
        comments: comments,
        news: news,
        imageUrl: imageUrl,
        volume24hr: volume24hr,
        lastTradePrice: lastTradePrice,
        bestBid: bestBid,
        bestAsk: bestAsk,
        spread: spread,
        clobTokenId: clobTokenId,
        liquidityNum: liquidityNum,
        competitive: competitive,
      );
}

class MarketComment {
  const MarketComment({
    required this.author,
    required this.text,
    required this.sentiment,
  });

  final String author;
  final String text;
  final MarketSide sentiment;
}

class MarketNews {
  const MarketNews({
    required this.source,
    required this.title,
    required this.age,
  });

  final String source;
  final String title;
  final String age;
}
