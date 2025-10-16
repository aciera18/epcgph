import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'cooperative_detail_page.dart';

class CooperativePage extends StatefulWidget {
  const CooperativePage({super.key});

  @override
  State<CooperativePage> createState() => _CooperativePageState();
}

class _CooperativePageState extends State<CooperativePage> {
  late Future<List<Map<String, dynamic>>> cooperatives;

  @override
  void initState() {
    super.initState();
    cooperatives = fetchCooperatives();
  }

  Future<List<Map<String, dynamic>>> fetchCooperatives() async {
    final url = Uri.parse('https://pcgfinance.com.ph/LMS/get_cooperatives.php');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map<Map<String, dynamic>>((coop) {
        return {
          'id': coop['id'],
          'name': coop['name'],
          'logo_url': (coop['logo_url'] as String).replaceAll(r'\/', '/'),
          'main_address': coop['main_address'],
          'contact_number': coop['contact_number'],
          'description': coop['description'],
        };
      }).toList();
    } else {
      throw Exception('Failed to load cooperatives');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Financing Cooperative"),
        backgroundColor: Colors.teal[700],
        elevation: 2,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: cooperatives,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No cooperatives found.'));
          } else {
            final coops = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: coops.length,
              itemBuilder: (context, index) {
                final coop = coops[index];
                final logoUrl = coop['logo_url'] ?? '';
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CooperativeDetailPage(cooperative: coop),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: Colors.grey.withOpacity(0.3),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Logo
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: logoUrl.isNotEmpty
                                ? CachedNetworkImageProvider(logoUrl)
                                : null,
                            child: logoUrl.isEmpty
                                ? const Icon(Icons.apartment, size: 30)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          // Name and Address
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  coop['name'] ?? 'Unnamed Cooperative',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  coop['main_address'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  coop['contact_number'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
