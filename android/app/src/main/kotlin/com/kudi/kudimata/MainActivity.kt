package com.kudi.kudimata

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity — local_auth's Android
// implementation shows the system BiometricPrompt, which is a fragment and
// therefore requires a FragmentActivity host. With plain FlutterActivity the
// prompt throws `no_fragment_activity` at runtime, which is exactly the kind
// of failure that only shows up on a real device (2026-08-24).
class MainActivity : FlutterFragmentActivity()
