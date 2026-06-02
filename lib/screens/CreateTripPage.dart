import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:untitled/providers/auth_provider.dart';
import '../l10n/app_localizations.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class CreateTripPage extends StatefulWidget {
  const CreateTripPage({super.key});

  @override
  State<CreateTripPage> createState() => _CreateTripPageState();
}

class _CreateTripPageState extends State<CreateTripPage> {
  final _titleController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  List<String> _destinations = [];
  String? _selectedDestination;

  @override
  void initState() {
    super.initState();
    _fetchDestinations();
  }

  Future<void> _fetchDestinations() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('places').get();
      setState(() {
        _destinations = snapshot.docs.map((doc) => doc['title'] as String).toList();
      });
    } catch (e) {
      final localizations = AppLocalizations.of(context);
      print('${localizations.translate('error_loading_destinations')}$e');
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(data: isDark ? ThemeData.dark() : ThemeData.light(), child: child!);
      },
    );
    if (picked != null) {
      setState(() {
        isStart ? _startDate = picked : _endDate = picked;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submitForm() async {
    final localizations = AppLocalizations.of(context);
    final user = context.read<AuthProvider>().user;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.translate('user_not_logged_in'))),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty || _selectedDestination == null || _startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.translate('complete_required_fields'))),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.translate('end_date_before_start'))),
      );
      return;
    }

    try {
      // Fetch the selected place's document from 'places' collection
      final placeSnapshot = await FirebaseFirestore.instance
          .collection('places')
          .where('title', isEqualTo: _selectedDestination)
          .limit(1)
          .get();

      String? imageUrl;
      if (placeSnapshot.docs.isNotEmpty) {
        imageUrl = placeSnapshot.docs.first.data()['imageUrl'] as String?;
      }

      // Save itinerary with destination image
      await FirebaseFirestore.instance.collection('itineraries').add({
        'title': _titleController.text.trim(),
        'destination': _selectedDestination,
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'createdAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'places': [],
        'isPublic': false,
        'imageUrl': imageUrl ?? '', // fallback empty if not found
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.translate('trip_created_success'))),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${localizations.translate('trip_creation_failed')}$e')),
      );
    }
  }

  Widget _labeledField(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Theme.of(context).textTheme.bodyLarge?.color)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _inputBoxDecoration({String? hintText, IconData? icon}) {    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
      prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF4080FF)) : null,
      filled: true,
      fillColor: isDark ? Colors.grey[900] : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? Colors.grey[700]! : const Color(0xFFDADCE0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? Colors.grey[700]! : const Color(0xFFDADCE0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(localizations.translate('create_trip_title')),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        foregroundColor: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _labeledField(
              localizations.translate('trip_title_label'),
              TextField(
                controller: _titleController,
                style: theme.textTheme.bodyLarge,
                decoration: _inputBoxDecoration(
                  hintText: localizations.translate('enter_trip_title'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _labeledField(
  localizations.translate('destination_label'),
  DropdownButtonHideUnderline(
    child: DropdownButton2<String>(
      isExpanded: true,
      hint: Text(
        localizations.translate('select_destination'),
        style: Theme.of(context).textTheme.bodyLarge,
        overflow: TextOverflow.ellipsis,
      ),
      items: _destinations
          .map((d) => DropdownMenuItem<String>(
                value: d,
                child: Text(
                  d,
                  style: Theme.of(context).textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      value: _selectedDestination,
      onChanged: (value) => setState(() => _selectedDestination = value),

      // ✅ Styling the "input box"
      buttonStyleData: ButtonStyleData(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
          color: Theme.of(context).cardColor,
        ),
      ),

      // ✅ Arrow icon styling
      iconStyleData: const IconStyleData(
        icon: Icon(Icons.keyboard_arrow_down_rounded),
        iconSize: 24,
        iconEnabledColor: Colors.grey,
      ),

      // ✅ Dropdown list styling
      dropdownStyleData: DropdownStyleData(
        maxHeight: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).cardColor,
        ),
        offset: const Offset(0, 0), // 👈 ensures it opens right below
      ),

      // ✅ Items styling
      menuItemStyleData: const MenuItemStyleData(
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: 14),
      ),
    ),
  ),
),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _labeledField(
                    localizations.translate('start_date_label'),
                    GestureDetector(
                      onTap: () => _pickDate(isStart: true),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: Colors.grey[500], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(_startDate),
                              style: theme.textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _labeledField(
                    localizations.translate('end_date_label'),
                    GestureDetector(
                      onTap: () => _pickDate(isStart: false),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: Colors.grey[500], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(_endDate),
                              style: theme.textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color.fromARGB(255, 255, 193, 7),
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                child: Text(localizations.translate('create_trip_title')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
