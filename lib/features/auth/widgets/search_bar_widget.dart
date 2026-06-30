// lib/features/auth/widgets/search_bar_widget.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';

class SearchBarWidget extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool enabled;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool showClearButton;
  final String? errorText;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.showClearButton = true,
    this.errorText,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  bool _hasFocus = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      // Update clear button visibility
    });
    widget.onChanged?.call(widget.controller.text);
  }

  void _clearText() {
    widget.controller.clear();
    widget.onClear?.call();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _hasError = widget.errorText != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 44, // comfortable input height + ≥44px touch target (a11y)
          decoration: AppTheme.getGlassDecoration(
            color: _hasError 
                ? AppTheme.error.withValues(alpha: 0.05)
                : _hasFocus 
                    ? AppTheme.surfacePrimary
                    : AppTheme.neutral50,
            borderRadius: AppTheme.borderRadius8, // Smaller radius
            border: Border.all(
              color: _hasError 
                  ? AppTheme.error
                  : _hasFocus 
                      ? AppTheme.greenPrimary
                      : AppTheme.neutral300,
              width: _hasError || _hasFocus ? 1.5 : 1.0, // Reduced border width
            ),
          ),
          child: Focus(
            onFocusChange: (hasFocus) {
              setState(() {
                _hasFocus = hasFocus;
              });
            },
            child: TextField(
              controller: widget.controller,
              enabled: widget.enabled,
              style: AppTheme.bodyMedium.copyWith(
                fontSize: 14, // legible input text
                color: widget.enabled ? AppTheme.neutral900 : AppTheme.neutral400,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: AppTheme.bodyMedium.copyWith(
                  fontSize: 14, // legible hint text
                  color: AppTheme.neutral400,
                ),
                
                // Prefix Icon
                prefixIcon: widget.prefixIcon ?? Container(
                  width: 32, // Fixed small width
                  padding: const EdgeInsets.all(6), // Reduced padding
                  margin: const EdgeInsets.only(left: 6, right: 4), // Reduced margins
                  decoration: BoxDecoration(
                    color: _hasFocus ? AppTheme.greenPrimary : AppTheme.neutral300,
                    borderRadius: AppTheme.borderRadius8, // Smaller radius
                  ),
                  child: Icon(
                    Icons.search,
                    size: 14, // Reduced icon size
                    color: _hasFocus ? Colors.white : AppTheme.neutral600,
                  ),
                ),
                
                // Suffix Icons
                suffixIcon: _buildSuffixIcons(context),
                
                // Border styling
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                
                // Content padding
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8, // Reduced padding
                  horizontal: 8, // Reduced padding
                ),
                
                // Disable default error text (we handle it below)
                errorText: null,
              ),
            ),
          ),
        ),
        
        // Custom error text
        if (_hasError) ...[
          const SizedBox(height: 4), // Reduced spacing
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8), // Reduced padding
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 12, // Reduced icon size
                  color: AppTheme.error,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.errorText!,
                    style: AppTheme.bodySmall.copyWith(
                      fontSize: 10, // Reduced font size
                      color: AppTheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget? _buildSuffixIcons(BuildContext context) {
    final List<Widget> icons = [];

    // Clear button
    if (widget.showClearButton && widget.controller.text.isNotEmpty) {
      icons.add(
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.enabled ? _clearText : null,
            borderRadius: AppTheme.borderRadius8, // Smaller radius
            child: Container(
              padding: const EdgeInsets.all(6), // Reduced padding
              child: Icon(
                Icons.close,
                size: 14, // Reduced icon size
                color: widget.enabled ? AppTheme.neutral600 : AppTheme.neutral400,
              ),
            ),
          ),
        ),
      );
    }

    // Custom suffix icon
    if (widget.suffixIcon != null) {
      icons.add(widget.suffixIcon!);
    }

    if (icons.isEmpty) return null;

    if (icons.length == 1) return icons.first;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: icons,
    );
  }
}

// Enhanced search bar for specific use cases
class AdvancedSearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterPressed;
  final VoidCallback? onMicPressed;
  final bool showFilterButton;
  final bool showMicButton;
  final bool enabled;
  final String? errorText;
  final int? resultsCount;

  const AdvancedSearchBarWidget({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onFilterPressed,
    this.onMicPressed,
    this.showFilterButton = false,
    this.showMicButton = false,
    this.enabled = true,
    this.errorText,
    this.resultsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SearchBarWidget(
          controller: controller,
          hintText: hintText,
          onChanged: onChanged,
          enabled: enabled,
          errorText: errorText,
          suffixIcon: _buildAdvancedSuffixIcons(context),
        ),
        
        // Results count
        if (resultsCount != null) ...[
          const SizedBox(height: 6), // Reduced spacing
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8), // Reduced padding
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$resultsCount result${resultsCount == 1 ? '' : 's'} found',
                style: AppTheme.bodySmall.copyWith(
                  fontSize: 10, // Reduced font size
                  color: AppTheme.neutral500,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget? _buildAdvancedSuffixIcons(BuildContext context) {
    final List<Widget> icons = [];

    // Filter button
    if (showFilterButton) {
      icons.add(
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onFilterPressed : null,
            borderRadius: AppTheme.borderRadius8, // Smaller radius
            child: Container(
              padding: const EdgeInsets.all(6), // Reduced padding
              margin: const EdgeInsets.symmetric(horizontal: 2), // Reduced margin
              decoration: BoxDecoration(
                color: AppTheme.greenPrimary.withValues(alpha: 0.1),
                borderRadius: AppTheme.borderRadius8,
              ),
              child: Icon(
                Icons.tune,
                size: 14, // Reduced icon size
                color: enabled ? AppTheme.greenPrimary : AppTheme.neutral400,
              ),
            ),
          ),
        ),
      );
    }

    // Microphone button
    if (showMicButton) {
      icons.add(
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onMicPressed : null,
            borderRadius: AppTheme.borderRadius8, // Smaller radius
            child: Container(
              padding: const EdgeInsets.all(6), // Reduced padding
              margin: const EdgeInsets.symmetric(horizontal: 2), // Reduced margin
              decoration: BoxDecoration(
                color: AppTheme.greenPrimary.withValues(alpha: 0.1),
                borderRadius: AppTheme.borderRadius8,
              ),
              child: Icon(
                Icons.mic,
                size: 14, // Reduced icon size
                color: enabled ? AppTheme.greenPrimary : AppTheme.neutral400,
              ),
            ),
          ),
        ),
      );
    }

    if (icons.isEmpty) return null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: icons,
    );
  }
}

// Compact search bar for tight spaces
class CompactSearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const CompactSearchBarWidget({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32, // Very small height
      decoration: AppTheme.getGlassDecoration(
        color: AppTheme.neutral50,
        borderRadius: BorderRadius.circular(16), // More rounded
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        style: AppTheme.bodySmall.copyWith(
          fontSize: 11, // Very small font
          color: enabled ? AppTheme.neutral900 : AppTheme.neutral400,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTheme.bodySmall.copyWith(
            fontSize: 11, // Very small font
            color: AppTheme.neutral400,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 14, // Small icon
            color: AppTheme.neutral500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 6, // Very small padding
            horizontal: 8, // Very small padding
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// Micro search bar - ultra compact
class MicroSearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const MicroSearchBarWidget({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28, // Ultra small height
      decoration: AppTheme.getGlassDecoration(
        color: AppTheme.neutral50,
        borderRadius: BorderRadius.circular(14), // Pill shape
        border: Border.all(color: AppTheme.neutral300, width: 0.5),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(
              Icons.search,
              size: 12, // Very small icon
              color: AppTheme.neutral500,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              style: AppTheme.bodySmall.copyWith(
                fontSize: 10, // Ultra small font
                color: enabled ? AppTheme.neutral900 : AppTheme.neutral400,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTheme.bodySmall.copyWith(
                  fontSize: 10, // Ultra small font
                  color: AppTheme.neutral400,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 8,
                ),
              ),
              onChanged: onChanged,
            ),
          ),
          if (controller.text.isNotEmpty)
            InkWell(
              onTap: enabled ? () => controller.clear() : null,
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.close,
                  size: 12, // Very small icon
                  color: AppTheme.neutral500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
