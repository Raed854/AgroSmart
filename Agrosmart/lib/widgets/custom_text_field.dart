import 'package:flutter/material.dart';

import '../main.dart';

class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?) validator;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      textInputAction: textInputAction,
      style: const TextStyle(
        color: inkGreen,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: mutedGreen, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        labelStyle: const TextStyle(color: mutedGreen, fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFFAAB5AD), fontSize: 14),
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _border(color: freshGreen, width: 1.5),
        errorBorder: _border(color: const Color(0xFFD66555)),
        focusedErrorBorder: _border(
          color: const Color(0xFFD66555),
          width: 1.5,
        ),
      ),
    );
  }

  OutlineInputBorder _border({Color color = borderGreen, double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
