import 'package:appwrite/appwrite.dart';

void main() {
  print('Checking appwrite package for TablesDB...');
  final client = Client();
  
  // This will cause a compile error if TablesDB doesn't exist
  final tablesDB = TablesDB(client);
  print('SUCCESS: TablesDB class is available!');
}
