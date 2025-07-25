// lib/features/pricing/presentation/pricing_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});
  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  bool yearly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Pricing',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Toggle Monthly / Yearly
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Monthly', style: TextStyle(color: Colors.white70)),
                Switch(
                  value: yearly,
                  onChanged: (v) => setState(() => yearly = v),
                  activeColor: Colors.cyanAccent,
                ),
                const Text('Yearly', style: TextStyle(color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildPlanCard('Free', '0', ['Basic features'], false),
                  const SizedBox(height: 16),
                  _buildPlanCard('Pro', yearly ? '99/yr' : '9.99/mo', [
                    'All Free features',
                    'Priority support',
                  ], true),
                  const SizedBox(height: 16),
                  _buildPlanCard('Premium', yearly ? '199/yr' : '19.99/mo', [
                    'All Pro features',
                    'Advanced analytics',
                  ], true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(
    String title,
    String price,
    List<String> features,
    bool isPaid,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '\$$price',
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              for (var f in features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check,
                        size: 20,
                        color: Colors.cyanAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPaid
                        ? Colors.cyanAccent
                        : Colors.white24,
                  ),
                  onPressed: isPaid
                      ? () {
                          // TODO: handle purchase
                        }
                      : null,
                  child: Text(
                    isPaid ? 'Choose' : 'Current',
                    style: TextStyle(
                      color: isPaid ? Colors.black : Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
