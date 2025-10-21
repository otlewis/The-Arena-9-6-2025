#!/bin/bash
# Automated fix for Color.withValues() compatibility
# Replaces all .withValues(alpha: X) with .withOpacity(X) for SDK compatibility

echo "🔧 Fixing Color.withValues() compatibility issues..."

# Only process active .dart files (not .disabled or .backup)
files=$(find lib -name "*.dart" -type f ! -name "*.disabled" ! -name "*.backup")

count=0
for file in $files; do
  # Replace .withValues(alpha: X) with .withOpacity(X)
  # This regex handles various formatting: spaces, no spaces, etc.
  if grep -q "\.withValues(" "$file"; then
    sed -i.bak 's/\.withValues(alpha: *\([^)]*\))/\.withOpacity(\1)/g' "$file"
    ((count++))
    echo "  ✓ Fixed: $file"
  fi
done

echo ""
echo "✅ Fixed $count files"
echo "📊 Verifying changes..."

# Count remaining withValues() in active files
remaining=$(find lib -name "*.dart" -type f ! -name "*.disabled" ! -name "*.backup" -exec grep -h "\.withValues(" {} \; | wc -l | tr -d ' ')

if [ "$remaining" -eq 0 ]; then
  echo "✅ All .withValues() calls successfully replaced!"
  echo "🧹 Cleaning up backup files..."
  find lib -name "*.dart.bak" -type f -delete
  echo "✅ Done!"
else
  echo "⚠️  Warning: $remaining .withValues() calls still remain"
  echo "   These may need manual review"
fi
