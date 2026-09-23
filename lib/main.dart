import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/app_config.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/breed_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/stats_provider.dart';
import 'screens/auth_gate.dart';
import 'services/dog_photo_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuration first: SupabaseBootstrap reads it, and both are written to
  // tolerate a missing .env so the app still starts for someone who has just
  // cloned the repo.
  await AppConfig.load();
  await SupabaseBootstrap.initialise();

  // Draw behind the status and navigation bars. The Breed Detail hero is meant
  // to run edge to edge underneath the status bar, which is impossible while
  // the system reserves an opaque strip for it. Every screen already wraps its
  // content in SafeArea, and the bottom nav pads itself by
  // MediaQuery.padding.bottom, so nothing ends up under the notch or the
  // gesture bar as a result.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(_overlayStyle);

  runApp(const PawPediaApp());
}

/// Dark icons on a transparent bar: the app is a light theme throughout, so
/// light status-bar icons would be invisible against cream.
const SystemUiOverlayStyle _overlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarDividerColor: Colors.transparent,
);

class PawPediaApp extends StatelessWidget {
  const PawPediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider()..initialise(),
        ),
        ChangeNotifierProvider<BreedProvider>(
          create: (_) => BreedProvider()..load(),
        ),
        ChangeNotifierProvider<StatsProvider>(
          create: (_) => StatsProvider()..initialise(),
        ),
        // The third-party Dog CEO API. One instance, so its breed list is
        // fetched once per launch rather than once per screen.
        Provider<DogPhotoService>(
          create: (_) => DogPhotoService(),
          dispose: (_, DogPhotoService service) => service.dispose(),
        ),

        // Favourites and profile follow whoever is signed in. Wiring them
        // through proxies means a sign-out cannot leave one account's data on
        // screen for the next person to log in.
        ChangeNotifierProxyProvider<AuthProvider, FavoritesProvider>(
          create: (_) => FavoritesProvider(),
          update: (_, AuthProvider auth, FavoritesProvider? favorites) {
            final FavoritesProvider provider = favorites ?? FavoritesProvider();
            provider.syncWithAuth(userId: auth.userId, isGuest: auth.isGuest);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>(
          create: (_) => ProfileProvider(),
          update: (_, AuthProvider auth, ProfileProvider? profile) {
            final ProfileProvider provider = profile ?? ProfileProvider();
            provider.syncWithAuth(
              userId: auth.userId,
              fallbackName: auth.metadataName,
            );
            return provider;
          },
        ),
      ],
      child: MaterialApp(
        title: 'PawPedia',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // Routes that push an AppBar would otherwise reset the overlay style;
        // re-applying it here keeps the status bar transparent everywhere.
        builder: (BuildContext context, Widget? child) =>
            AnnotatedRegion<SystemUiOverlayStyle>(
          value: _overlayStyle,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const AuthGate(),
      ),
    );
  }
}
