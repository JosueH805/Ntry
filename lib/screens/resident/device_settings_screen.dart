import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ntry_mobile/database/device_helper.dart';
import 'package:ntry_mobile/providers/user_provider.dart';


class DeviceSettingsScreen extends StatefulWidget {
  const DeviceSettingsScreen({super.key});

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  DeviceData? _device;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDevice();
  }

  Future<void> _loadDevice() async {
    final lockId = userProviderInstance.lockId;
    if (lockId == null) {
      setState(() => _loading = false);
      return;
    }
    final device = await DeviceHelper().getDeviceByLockId(lockId);
    if (mounted) {
      setState(() {
        _device = device;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Device Settings',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _device == null
              ? _buildNoDevice(colors)
              : _buildDevice(colors),
    );
  }

  //No device registered UI

  Widget _buildNoDevice(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sensors_off_rounded,
                size: 64, color: colors.onSurfaceVariant),
            const SizedBox(height: 20),
            Text(
              'No device registered',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Contact your building administrator to pair a lock device to your account.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  //Device info

  Widget _buildDevice(ColorScheme colors) {
  final device = _device!;
  final lastUnlocked = device.lastUnlocked;
  final lastUnlockedText = lastUnlocked == null ? 'Never' : _formatLastSeen(lastUnlocked);

  return ListView(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    children: [
      // Status badge
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sensors_rounded,
                  size: 16, color: colors.onPrimaryContainer),
              const SizedBox(width: 6),
              Text(
                'Device Registered',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),

      _SectionCard(
        title: 'Device Info',
        colors: colors,
        children: [
          _InfoRow(label: 'Name',      value: device.deviceName ?? '—', colors: colors),
          _InfoRow(label: 'Device ID', value: device.deviceId ?? '—',   colors: colors, monospace: true),
          _InfoRow(label: 'Room',      value: device.room ?? '—',       colors: colors),
          _InfoRow(label: 'Location',  value: device.location ?? '—',   colors: colors),
        ],
      ),
      const SizedBox(height: 16),

      _SectionCard(
        title: 'Status',
        colors: colors,
        children: [
          _InfoRow(label: 'Lock status',   value: device.status ?? '—',     colors: colors),
          _InfoRow(label: 'Last unlocked', value: lastUnlockedText,          colors: colors),
          _InfoRow(label: 'Lock ID',       value: device.lockId,             colors: colors, monospace: true),
        ],
      ),
    ],
  );
}

  String _formatLastSeen(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

//Section card widget for grouping related device info with a title and styled container

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.colors,
    required this.children,
  });

  final String title;
  final ColorScheme colors;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outline),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
//Info row widget for displaying a label and value pair, with optional monospace font and copy button
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.colors,
    this.monospace = false,
    this.copyable = false,
  });

  final String label;
  final String value;
  final ColorScheme colors;
  final bool monospace;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: monospace
                  ? TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: colors.onSurface,
                    )
                  : GoogleFonts.inter(
                      fontSize: 14,
                      color: colors.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
            ),
          ),
          if (copyable && value != '—') ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Icon(Icons.copy_rounded,
                  size: 16, color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}