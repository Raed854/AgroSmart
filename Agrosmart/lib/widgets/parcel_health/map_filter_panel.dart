import 'package:flutter/material.dart';

import '../../models/parcel_health.dart';
import 'health_palette.dart';

class MapFilterPanel extends StatelessWidget {
  const MapFilterPanel({
    super.key,
    required this.parcels,
    required this.missions,
    required this.selectedParcel,
    required this.selectedMission,
    required this.typeFilter,
    required this.severityFilter,
    required this.onParcelChanged,
    required this.onMissionChanged,
    required this.onTypeChanged,
    required this.onSeverityChanged,
    this.onAddParcel,
    this.enabled = true,
  });

  final List<Parcel> parcels;
  final List<DroneMission> missions;
  final Parcel? selectedParcel;
  final DroneMission? selectedMission;
  final AnomalyType? typeFilter;
  final Severity? severityFilter;
  final ValueChanged<Parcel> onParcelChanged;
  final ValueChanged<DroneMission> onMissionChanged;
  final ValueChanged<AnomalyType?> onTypeChanged;
  final ValueChanged<Severity?> onSeverityChanged;
  final VoidCallback? onAddParcel;

  /// Parcel and mission pickers are locked while data is loading.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: healthCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: healthPrimary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Map filters',
                  style: TextStyle(
                    color: healthInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onAddParcel != null)
                TextButton.icon(
                  onPressed: enabled ? onAddParcel : null,
                  style: TextButton.styleFrom(
                    foregroundColor: healthPrimary,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: const Text(
                    'New parcel',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Dropdown<Parcel>(
                  label: 'Parcel',
                  icon: Icons.landscape_outlined,
                  value: selectedParcel,
                  items: parcels,
                  itemLabel: (parcel) => parcel.name,
                  onChanged: enabled ? onParcelChanged : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Dropdown<DroneMission>(
                  label: 'Drone mission',
                  icon: Icons.flight_rounded,
                  value: selectedMission,
                  items: missions,
                  itemLabel: (mission) => formatDate(mission.flownAt),
                  onChanged: enabled ? onMissionChanged : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Anomaly type'),
          _ChipRow<AnomalyType>(
            values: AnomalyType.values,
            selected: typeFilter,
            label: (type) => type.label,
            icon: anomalyIcon,
            color: (_) => healthPrimary,
            onSelected: onTypeChanged,
          ),
          const SizedBox(height: 12),
          const _SectionLabel('Severity'),
          _ChipRow<Severity>(
            values: Severity.values,
            selected: severityFilter,
            label: (severity) => severity.label,
            color: severityColor,
            onSelected: onSeverityChanged,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: healthMuted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: .3,
      ),
    ),
  );
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: items.contains(value) ? value : null,
      key: ValueKey(value),
      isExpanded: true,
      icon: const Icon(Icons.expand_more_rounded, color: healthPrimary),
      borderRadius: BorderRadius.circular(14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: healthMuted, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: healthPrimary),
        prefixIconConstraints: const BoxConstraints(minWidth: 36),
        isDense: true,
        filled: true,
        fillColor: healthBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: healthBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: healthBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: healthPrimary, width: 1.5),
        ),
      ),
      style: const TextStyle(
        color: healthInk,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      items: [
        for (final item in items)
          DropdownMenuItem(
            value: item,
            child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged == null
          ? null
          : (item) {
              if (item != null) onChanged!(item);
            },
    );
  }
}

class _ChipRow<T> extends StatelessWidget {
  const _ChipRow({
    required this.values,
    required this.selected,
    required this.label,
    required this.color,
    required this.onSelected,
    this.icon,
  });

  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final Color Function(T) color;
  final IconData Function(T)? icon;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget chip({
      required String text,
      required bool isSelected,
      required Color accent,
      required VoidCallback onTap,
      IconData? leading,
    }) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: isSelected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        avatar: leading == null
            ? null
            : Icon(
                leading,
                size: 16,
                color: isSelected ? Colors.white : accent,
              ),
        label: Text(text),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : healthInk,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        selectedColor: accent,
        backgroundColor: Colors.white,
        side: BorderSide(color: isSelected ? accent : healthBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(
            text: 'All',
            isSelected: selected == null,
            accent: healthPrimary,
            onTap: () => onSelected(null),
          ),
          for (final value in values)
            chip(
              text: label(value),
              isSelected: selected == value,
              accent: color(value),
              leading: icon?.call(value),
              // Tapping the active chip again resets the filter to "All".
              onTap: () => onSelected(selected == value ? null : value),
            ),
        ],
      ),
    );
  }
}
