#!/usr/bin/env python3
"""
Debug Print Replacer - Automated tool to replace debug prints with structured logging
"""

import re
import os
import sys

def replace_debug_prints(file_path):
    """Replace debugPrint calls with structured logging"""
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Check if AppLogger import already exists
    has_logger_import = 'import \'../core/logging/app_logger.dart\'' in content or 'import \'../../core/logging/app_logger.dart\'' in content or 'import \'../../../core/logging/app_logger.dart\'' in content
    
    # Add import if needed
    if not has_logger_import and ('debugPrint(' in content or 'print(' in content):
        # Find the import section
        import_pattern = r'(import [^;]+;)'
        imports = re.findall(import_pattern, content)
        
        if imports:
            # Determine the correct relative path based on file location
            if '/screens/' in file_path:
                logger_import = "import '../core/logging/app_logger.dart';"
            elif '/features/' in file_path:
                logger_import = "import '../../../core/logging/app_logger.dart';"
            elif '/models/' in file_path:
                logger_import = "import '../core/logging/app_logger.dart';"
            else:
                logger_import = "import '../core/logging/app_logger.dart';"
            
            # Add import after the last import
            last_import = imports[-1]
            content = content.replace(last_import, last_import + '\n' + logger_import)
    
    # Pattern to match debugPrint statements
    debug_patterns = [
        # debugPrint with simple string
        (r"debugPrint\('([^']+)'\);", lambda m: f"AppLogger().debug('{m.group(1)}');"),
        
        # debugPrint with string interpolation
        (r'debugPrint\("([^"]+)"\);', lambda m: f'AppLogger().debug("{m.group(1)}");'),
        
        # debugPrint with variable interpolation - convert to proper logging
        (r"debugPrint\('([^']*\$[^']+)'\);", lambda m: f"AppLogger().debug('{m.group(1)}');"),
        (r'debugPrint\("([^"]*\$[^"]+)"\);', lambda m: f'AppLogger().debug("{m.group(1)}");'),
    ]
    
    # Apply replacements
    original_content = content
    for pattern, replacement in debug_patterns:
        content = re.sub(pattern, replacement, content)
    
    # Convert specific debug messages to appropriate log levels
    conversions = [
        # Error messages
        (r"AppLogger\(\)\.debug\('❌ ([^']+)'\);", r"AppLogger().error('\1');"),
        (r'AppLogger\(\)\.debug\("❌ ([^"]+)"\);', r'AppLogger().error("\1");'),
        
        # Warning messages  
        (r"AppLogger\(\)\.debug\('⚠️ ([^']+)'\);", r"AppLogger().warning('\1');"),
        (r'AppLogger\(\)\.debug\("⚠️ ([^"]+)"\);', r'AppLogger().warning("\1");'),
        
        # Info messages
        (r"AppLogger\(\)\.debug\('✅ ([^']+)'\);", r"AppLogger().info('\1');"),
        (r'AppLogger\(\)\.debug\("✅ ([^"]+)"\);', r'AppLogger().info("\1");'),
        
        (r"AppLogger\(\)\.debug\('🔔 ([^']+)'\);", r"AppLogger().info('\1');"),
        (r'AppLogger\(\)\.debug\("🔔 ([^"]+)"\);', r'AppLogger().info("\1");'),
        
        (r"AppLogger\(\)\.debug\('🎯 ([^']+)'\);", r"AppLogger().info('\1');"),
        (r'AppLogger\(\)\.debug\("🎯 ([^"]+)"\);', r'AppLogger().info("\1");'),
        
        (r"AppLogger\(\)\.debug\('🏛️ ([^']+)'\);", r"AppLogger().info('\1');"),
        (r'AppLogger\(\)\.debug\("🏛️ ([^"]+)"\);', r'AppLogger().info("\1");'),
        
        (r"AppLogger\(\)\.debug\('🚀 ([^']+)'\);", r"AppLogger().info('\1');"),
        (r'AppLogger\(\)\.debug\("🚀 ([^"]+)"\);', r'AppLogger().info("\1");'),
    ]
    
    for pattern, replacement in conversions:
        content = re.sub(pattern, replacement, content)
    
    # Write back only if changes were made
    if content != original_content:
        with open(file_path, 'w') as f:
            f.write(content)
        return True
    return False

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 debug_print_replacer.py <file_path>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        sys.exit(1)
    
    if replace_debug_prints(file_path):
        print(f"✅ Replaced debug prints in {file_path}")
    else:
        print(f"ℹ️ No debug prints found in {file_path}")

if __name__ == "__main__":
    main()