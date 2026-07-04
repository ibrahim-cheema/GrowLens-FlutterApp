import 'package:flutter/material.dart';

class WelcomeHeader extends StatelessWidget {
  final int plants;
  final int healthy;
  final int needsCare;

  const WelcomeHeader({
    super.key,
    this.plants = 0,
    this.healthy = 0,
    this.needsCare = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF447804), // #447804
            Color(0xFF346E05), // #346E05
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF243C07).withValues(alpha: 0.3), // #243C07
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good Morning! 👋',
            style: TextStyle(
              color: const Color(0xFFEEFB8F).withValues(alpha: 0.9), // #EEFB8F
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'GrowLens',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AI-powered gardening assistant',
            style: TextStyle(
              color: const Color(0xFF8FB25C).withValues(alpha: 0.8), // #8FB25C
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(plants.toString(), 'Plants'),
              _buildStatItem(healthy.toString(), 'Healthy'),
              _buildStatItem(needsCare.toString(), 'Needs Care'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFEEFB8F), // #EEFB8F for contrast
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF8FB25C).withValues(alpha: 0.8), // #8FB25C
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}