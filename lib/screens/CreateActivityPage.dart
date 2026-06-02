import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../l10n/app_localizations.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class CreateActivityPage extends StatefulWidget {
  final String itineraryId;

  const CreateActivityPage({super.key, required this.itineraryId});

  @override
  State<CreateActivityPage> createState() => _CreateActivityPageState();
}

class _CreateActivityPageState extends State<CreateActivityPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  List<Map<String, dynamic>> _places = [];
  String? _selectedPlaceId;

  @override
  void initState() {
    super.initState();
    _fetchPlaces();
  }

  Future<void> _fetchPlaces() async {
    final snapshot = await FirebaseFirestore.instance.collection('places').get();
    setState(() {
      _places = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'lat': data['lat'],
          'long': data['long'] ?? data['lng'] ?? data['longitude'],
        };
      }).toList();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null || _selectedTime == null || _selectedPlaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).translate('fill_required_fields'))),
      );
      return;
    }

    final activityDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    try {
      // find selected place data (id, title, lat, long)
      final selectedPlace = _places.firstWhere((p) => (p['id'] as String) == _selectedPlaceId);
      final placeTitle = selectedPlace['title'] ?? '';
      final placeLat = double.tryParse('${selectedPlace['lat']}') ?? 0.0;
      final placeLngRaw = selectedPlace['long'] ?? selectedPlace['lng'] ?? selectedPlace['longitude'];
      final placeLng = double.tryParse('$placeLngRaw') ?? 0.0;

      await FirebaseFirestore.instance
          .collection('itineraries')
          .doc(widget.itineraryId)
          .collection('activities')
          .add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': placeTitle,
        'placeId': _selectedPlaceId,
        'lat': placeLat,
        'lng': placeLng,
        'price': double.tryParse(_priceController.text.trim()) ?? 0,
        'datetime': Timestamp.fromDate(activityDateTime),
        'createdAt': FieldValue.serverTimestamp(),
        'isBooked': false,
      });

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).translate('error_creating_activity')}$e')),
      );
    }
  }

  InputDecoration _inputDecoration(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _labeledField(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.translate('add_activity_title'))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _labeledField(
                localizations.translate('activity_title_label'),
                TextFormField(
                  controller: _titleController,
                  decoration: _inputDecoration(localizations.translate('activity_title_hint')),
                  validator: (value) => value == null || value.isEmpty ? localizations.translate('required_field') : null,
                ),
              ),
              const SizedBox(height: 14),
              _labeledField(
                localizations.translate('description_label'),
                TextFormField(
                  controller: _descriptionController,
                  decoration: _inputDecoration(localizations.translate('description_hint')),
                  maxLines: 3,
                  validator: (value) => value == null || value.isEmpty ? localizations.translate('required_field') : null,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _labeledField(
                      localizations.translate('date_label'),
                      GestureDetector(
                        onTap: _pickDate,
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: _inputDecoration('YYYY-MM-DD'),
                            controller: TextEditingController(text: _formatDate(_selectedDate)),
                            validator: (_) => _selectedDate == null ? localizations.translate('required_field') : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _labeledField(
                      localizations.translate('time_label'),
                      GestureDetector(
                        onTap: _pickTime,
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: _inputDecoration('HH:MM'),
                            controller: TextEditingController(text: _formatTime(_selectedTime)),
                            validator: (_) => _selectedTime == null ? localizations.translate('required_field') : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _labeledField(
                localizations.translate('location_label'),
                DropdownButtonHideUnderline(
                  child: DropdownButton2<String>(
                    isExpanded: true,
                    hint: Text(localizations.translate('select_location')),
                    items: _places
                        .map((p) => DropdownMenuItem<String>(
                              value: p['id'] as String,
                              child: Text(p['title'] ?? '', overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    value: _selectedPlaceId,
                    onChanged: (value) => setState(() => _selectedPlaceId = value),
                    buttonStyleData: ButtonStyleData(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400),
                        color: Theme.of(context).cardColor,
                      ),
                    ),
                    iconStyleData: const IconStyleData(
                      icon: Icon(Icons.keyboard_arrow_down_rounded),
                      iconSize: 24,
                      iconEnabledColor: Colors.grey,
                    ),
                    dropdownStyleData: DropdownStyleData(
                      maxHeight: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Theme.of(context).cardColor,
                      ),
                    ),
                    menuItemStyleData: const MenuItemStyleData(
                      height: 48,
                      padding: EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _labeledField(
                localizations.translate('budget_label'),
                TextFormField(
                  controller: _priceController,
                  decoration: _inputDecoration(localizations.translate('enter_budget')),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 32),              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4080FF),
                  foregroundColor: Colors.white,
                ),
                onPressed: _submit,
                child: Text(localizations.translate('save_activity')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
