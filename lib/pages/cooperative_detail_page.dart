import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'branches_page.dart';

class CooperativeDetailPage extends StatelessWidget {
  final Map<String, dynamic> cooperative;
  const CooperativeDetailPage({super.key, required this.cooperative});

  /// Fetch branches from API
  Future<List<Map<String, dynamic>>> fetchBranches() async {
    final id = cooperative['id'].toString();
    final url = Uri.parse(
        'https://pcgfinance.com.ph/LMS/get_cooperative_branches.php?coop_id=$id');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> branchesData = data['branches'] ?? [];
      return branchesData.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load branches');
    }
  }

  @override
  Widget build(BuildContext context) {
    final logoUrl = (cooperative['logo_url'] as String?)?.replaceAll(r'\/', '/');

    return Scaffold(
      appBar: AppBar(
        title: Text(cooperative['name'] ?? 'Cooperative'),
        backgroundColor: Colors.teal[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo at the top
            if (logoUrl != null && logoUrl.isNotEmpty)
              Center(
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: logoUrl,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const SizedBox(
                        width: 120,
                        height: 120,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => const SizedBox(
                        width: 120,
                        height: 120,
                        child: Center(child: Icon(Icons.broken_image, size: 50)),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Details Card
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              shadowColor: Colors.grey.withOpacity(0.2),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Address
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.teal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cooperative['main_address'] ?? '-',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Contact Number
                    Row(
                      children: [
                        const Icon(Icons.phone, color: Colors.teal),
                        const SizedBox(width: 8),
                        Text(
                          cooperative['contact_number'] ?? '-',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Description
                    if (cooperative['description'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Description",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cooperative['description'],
                            style: const TextStyle(fontSize: 15, height: 1.3),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Branches Button
            // Branches Button
            FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchBranches(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('No branches found.');
                } else {
                  final branches = snapshot.data!;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00C853), Color(0xFF64DD17)], // Green gradient
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BranchesPage(branches: branches),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.location_city, size: 24, color: Colors.white),
                      label: const Text(
                        "View Branches",
                        style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }
              },
            ),

          ],
        ),
      ),
    );
  }
}
