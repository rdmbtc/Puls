#!/bin/bash
set -e

# Generate secrets.dart from Vercel environment variables
printf "const supabaseUrl = '%s';\nconst supabaseAnonKey = '%s';\n" \
  "$SUPABASE_URL" "$SUPABASE_ANON_KEY" > lib/core/secrets.dart

echo "Generated secrets.dart"

# Clone Flutter if not present
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable flutter
fi

# Build web
flutter/bin/flutter build web --wasm --release


