import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            backgroundColor: Colors.black,
            floating: true,
            title: Text("NEURAL STREAM DASHBOARD", style: TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold)),
          ),
          
          // 1. Market Environment & Trading Suggestions
          SliverToBoxAdapter(
            child: _buildEnvironmentHeader(),
          ),

          // 2. Categorized AI Stock Recommendations
          SliverToBoxAdapter(
            child: _buildStockRecommendations(),
          ),

          // 3. Modern Stock News Section
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(left: 20, top: 30, bottom: 10),
              child: Text("REAL-TIME INTELLIGENCE", style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.5)),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildNewsCard(index),
              childCount: 4, 
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF9D4EDD).withOpacity(0.3)),
        boxShadow: [BoxShadow(color: const Color(0xFF9D4EDD).withOpacity(0.1), blurRadius: 20, spreadRadius: -5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("OVERALL MARKET STATE", style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("BULLISH", style: TextStyle(color: Color(0xFF00FFA3), fontSize: 28, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF00FFA3).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Text("HIGH MOMENTUM", style: TextStyle(color: Color(0xFF00FFA3), fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 20),
          const Text("ALGORITHMIC SUGGESTION", style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: const Row(
              children: [
                Icon(Icons.insights, color: Color(0xFF9D4EDD), size: 18),
                SizedBox(width: 10),
                Text("Optimal Strategy: Intraday & Swing", style: TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStockRecommendations() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Color(0xFF00FFA3),
            labelColor: Color(0xFF00FFA3),
            unselectedLabelColor: Colors.white38,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: "TODAY"),
              Tab(text: "SHORT-TERM"),
              Tab(text: "LONG-TERM"),
            ],
          ),
          SizedBox(
            height: 120,
            child: TabBarView(
              children: [
                _buildRecommendationList(["RELIANCE", "TCS", "HDFCBANK"]),
                _buildRecommendationList(["ZOMATO", "TATASTEEL", "INFY"]),
                _buildRecommendationList(["ITC", "L&T", "SBIN"]),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRecommendationList(List<String> tickers) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: tickers.length,
      itemBuilder: (context, index) {
        return Container(
          width: 140,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F111A),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(tickers[index], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text("STRONG BUY", style: TextStyle(color: Color(0xFF00FFA3), fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNewsCard(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111A),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(10),
              image: const DecorationImage(
                image: NetworkImage("https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?auto=format&fit=crop&w=200&q=80"), // Placeholder Financial Image
                fit: BoxFit.cover,
              )
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Markets Rally on Positive FII Inflow and Tech Earnings", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text("2 hours ago • Financial Express", style: TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          )
        ],
      ),
    );
  }
}