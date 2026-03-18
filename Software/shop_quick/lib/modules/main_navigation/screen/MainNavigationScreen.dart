import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../favourite_stores/screen/FavouriteStoresScreen.dart';
import '../../my_receipts/screen/MyReceiptsScreen.dart';
import '../../receipt_upload/screen/ReceiptUploadScreen.dart';
import '../../shopping_input/screen/ShoppingInputScreen.dart';
import '../../../widgets/CurvedBottomNavBar.dart';
import '../controller/MainNavigationController.dart';

class MainNavigationScreen extends GetView<MainNavigationController> {
  const MainNavigationScreen({super.key});

  static const List<Widget> _pages = <Widget>[
    ShoppingInputScreen(),
    FavouriteStoresScreen(),
    ReceiptUploadScreen(),
    MyReceiptsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    controller;
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Obx(
        () => IndexedStack(
          index: controller.selectedIndex.value,
          children: _pages,
        ),
      ),
      bottomNavigationBar: isKeyboardVisible
          ? null
          : Obx(
              () => CurvedBottomNavBar(
                currentIndex: controller.selectedIndex.value,
                onTap: controller.changeTab,
                items: const <CurvedBottomNavBarItem>[
                  CurvedBottomNavBarItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: 'Home',
                  ),
                  CurvedBottomNavBarItem(
                    icon: Icons.list_alt_outlined,
                    activeIcon: Icons.list_alt,
                    label: 'Favourites',
                  ),
                  CurvedBottomNavBarItem(
                    icon: Icons.receipt_long_outlined,
                    activeIcon: Icons.receipt_long,
                    label: 'Upload',
                  ),
                  CurvedBottomNavBarItem(
                    icon: Icons.folder_copy_outlined,
                    activeIcon: Icons.folder_copy,
                    label: 'Receipts',
                  ),
                ],
              ),
            ),
    );
  }
}
