import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class CustomExpandableFab extends StatefulWidget {
  final VoidCallback onAddTap;
  final VoidCallback onLogTap;

  const CustomExpandableFab({
    Key? key,
    required this.onAddTap,
    required this.onLogTap,
  }) : super(key: key);

  @override
  State<CustomExpandableFab> createState() => _CustomExpandableFabState();
}

class _CustomExpandableFabState extends State<CustomExpandableFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: _isOpen ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
      parent: _controller,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildAction(
          icon: Icons.history,
          label: 'Log Aktivitas',
          onTap: widget.onLogTap,
        ),
        _buildAction(
          icon: Icons.note_add_outlined,
          label: 'Tambah Berkas',
          onTap: widget.onAddTap,
        ),
        _buildMainFab(),
      ],
    );
  }

  Widget _buildAction(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizeTransition(
      sizeFactor: _expandAnimation,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppConstants.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [AppConstants.primaryShadow],
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FloatingActionButton.small(
              heroTag: label,
              backgroundColor: isDark ? AppConstants.darkSurface : Colors.white,
              foregroundColor: isDark ? Colors.white : AppConstants.navyColor,
              elevation: 2,
              onPressed: () {
                _toggle();
                onTap();
              },
              child: Icon(icon),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainFab() {
    return FloatingActionButton(
      heroTag: 'main_fab_sira',
      backgroundColor: AppConstants.navyColor,
      foregroundColor: AppConstants.goldColor,
      elevation: 4,
      onPressed: _toggle,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Putar ikon sebanyak 45 derajat (0.785398 radian) saat terbuka
          return Transform.rotate(
            angle: _controller.value * 0.785398,
            child: const Icon(Icons.add, size: 28),
          );
        },
      ),
    );
  }
}
