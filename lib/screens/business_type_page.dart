import 'package:flutter/material.dart';
import 'package:whatsappchat/screens/profile_form_page.dart';
import 'package:whatsappchat/screens/chat_home.dart'; // 👈 ChatHomePage import kiya

class BusinessTypePage extends StatefulWidget {
  const BusinessTypePage({super.key});

  @override
  State<BusinessTypePage> createState() => _BusinessTypePageState();
}

class _BusinessTypePageState extends State<BusinessTypePage> {
  String? selectedType;

  final List<String> businessTypes = [
    "Manufacturer",
    "Retailer",
    "Trader",
    "Wholesaler",
    "Other"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // back action
          },
        ),
        title: const Text("Select Business Category"),
        centerTitle: true,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              // 👇 Skip karne par direct ChatHomePage open hoga
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatHomePage(),
                ),
              );
            },
            child: const Text(
              "Skip",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Choose your Business Category",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: businessTypes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final type = businessTypes[index];
                final isSelected = selectedType == type;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedType = type;
                    });
                  },
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          type,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.blue : Colors.black87,
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle,
                              color: Colors.blue, size: 22)
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (selectedType == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please select a Business Category"),
                        ),
                      );
                      return;
                    }

                    // ✅ Business Type select karne ke baad ProfileFormPage open hoga
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileFormPage(
                          selectedBusinessType: selectedType!,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    "Continue",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
