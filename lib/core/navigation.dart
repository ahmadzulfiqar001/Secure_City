import 'package:flutter/material.dart';

/// App-wide navigator key so services (e.g. AuthService reacting to a 401)
/// can redirect to the login screen without being handed a BuildContext.
final rootNavigatorKey = GlobalKey<NavigatorState>();
