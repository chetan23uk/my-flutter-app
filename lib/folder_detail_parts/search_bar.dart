part of '../folder_detail_screen.dart';

/// Simple inline search bar used in the AppBar
class _SearchBar extends StatefulWidget {
  final String initial;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.initial,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kToolbarHeight - 12,
      child: TextField(
        controller: _c,
        onChanged: widget.onChanged,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.white10,
          prefixIcon: const Icon(Icons.search),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
