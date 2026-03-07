import 'package:flutter/material.dart';
import '../widgets/sidebar.dart';
import '../widgets/navbar.dart';
import '../widgets/input_panel.dart';
import '../widgets/output_panel.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isMobile = screenWidth < 600;

    Widget mainContent = isDesktop
        ? const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: InputPanel()),
              SizedBox(width: 24),
              Expanded(child: OutputPanel()),
            ],
          )
        : const TabBarView(
            children: [
              Padding(
                padding: EdgeInsets.all(16.0),
                child: InputPanel(),
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: OutputPanel(),
              ),
            ],
          );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            const TopNavbar(),
            Expanded(
              child: Row(
                children: [
                  if (isDesktop) const HistorySidebar(),
                  Expanded(
                    child: Container(
                      color: AppTheme.backgroundGrey,
                      child: isDesktop
                          ? Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: mainContent,
                            )
                          : mainContent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        drawer: !isDesktop ? const Drawer(child: HistorySidebar()) : null,
        bottomNavigationBar: (isMobile || !isDesktop && screenWidth <= 900)
            ? Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: const TabBar(
                  labelColor: AppTheme.primaryBlue,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppTheme.primaryBlue,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: [
                    Tab(icon: Icon(Icons.edit_note), text: 'Input'),
                    Tab(icon: Icon(Icons.auto_awesome), text: 'Result'),
                  ],
                ),
              )
            : null,
      ),
    );
  }
}
