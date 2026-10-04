import 'package:flutter/material.dart';

const _labels = ['Inicio', 'Parcelas', 'Cultivos', 'Bitácora'];
const _icons = [
  Icons.home_outlined,
  Icons.grid_view_outlined,
  Icons.grass,
  Icons.menu_book_outlined,
];

/// Responds to available window space, including rotation and live resizing.
class AdaptiveRanchScaffold extends StatelessWidget {
  const AdaptiveRanchScaffold({
    super.key,
    required this.title,
    required this.actions,
    required this.body,
    required this.selectedIndex,
    required this.onSelected,
    required this.floatingActionButton,
  });
  final Widget title, body, floatingActionButton;
  final List<Widget> actions;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, space) {
      final sideNavigation = space.maxWidth >= 700 && space.maxHeight >= 500;
      final extended = space.maxWidth >= 1100;
      return Scaffold(
        appBar: AppBar(title: title, actions: actions),
        body: Row(
          children: [
            if (sideNavigation) ...[
              NavigationRail(
                extended: extended,
                selectedIndex: selectedIndex,
                onDestinationSelected: onSelected,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                backgroundColor: Colors.white,
                destinations: [
                  for (var i = 0; i < _labels.length; i++)
                    NavigationRailDestination(
                      icon: Icon(_icons[i]),
                      label: Text(_labels[i]),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
            ],
            Expanded(child: body),
          ],
        ),
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: sideNavigation
            ? null
            : NavigationBar(
                height: space.maxHeight < 500 ? 64 : null,
                labelBehavior:
                    space.maxWidth < 340 ||
                        MediaQuery.textScalerOf(context).scale(14) > 20
                    ? NavigationDestinationLabelBehavior.onlyShowSelected
                    : NavigationDestinationLabelBehavior.alwaysShow,
                selectedIndex: selectedIndex,
                onDestinationSelected: onSelected,
                destinations: [
                  for (var i = 0; i < _labels.length; i++)
                    NavigationDestination(
                      icon: Icon(_icons[i]),
                      label: _labels[i],
                    ),
                ],
              ),
      );
    },
  );
}

class ResponsiveRecordList extends StatelessWidget {
  const ResponsiveRecordList({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, space) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
      final columns = space.maxWidth >= 760 && !largeText ? 2 : 1;
      final width = (space.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class ResponsiveFormList extends StatelessWidget {
  const ResponsiveFormList({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, space) {
      final padding = space.maxWidth < 360 ? 12.0 : 24.0;
      final available = space.maxWidth - padding * 2;
      final twoColumns =
          available >= 680 && MediaQuery.textScalerOf(context).scale(14) <= 20;
      final fields = children.where((w) => w is! SizedBox).toList();
      return ListView(
        padding: EdgeInsets.all(padding),
        children: [
          Wrap(
            spacing: 20,
            runSpacing: 16,
            children: [
              for (var i = 0; i < fields.length; i++)
                SizedBox(
                  width: twoColumns && !_fullWidth(fields[i], i)
                      ? (available - 20) / 2
                      : available,
                  child: fields[i],
                ),
            ],
          ),
        ],
      );
    },
  );

  bool _fullWidth(Widget widget, int index) {
    final content = widget is Padding ? widget.child : widget;
    return index <= 1 ||
        content is Text ||
        content is FilledButton ||
        content?.key == const ValueKey('full-width-field') ||
        content?.key == const ValueKey('multiline-field');
  }
}
