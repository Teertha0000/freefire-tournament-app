const fs = require('fs');
const path = require('path');

const directory = 'c:/Users/mredu.PC/Desktop/Projects/FreeFire Tournament/tournament_v2/mobile_app/lib/screens/admin';

const files = fs.readdirSync(directory).filter(f => f.endsWith('.dart'));

for (const file of files) {
  const filePath = path.join(directory, file);
  let content = fs.readFileSync(filePath, 'utf8');
  
  if (content.includes('.stream(primaryKey: [')) {
    console.log(`Fixing ${file}`);
    
    // Replace:
    // return Supabase.instance.client
    //   .from('X')
    //   .stream(primaryKey: ['id'])
    //   .order(Y);
    //
    // With:
    // return () async* {
    //   while (true) {
    //     final data = await Supabase.instance.client.from('X').select().order(Y);
    //     yield data;
    //     await Future.delayed(const Duration(seconds: 10));
    //   }
    // }();
    
    const regex = /return\s+Supabase\.instance\.client\s*\.from\('([^']+)'\)\s*\.stream\([^)]+\)\s*\.order\(([^)]+)\);/g;
    content = content.replace(regex, (match, table, orderArgs) => {
        return `return () async* {\n    while (true) {\n      final data = await Supabase.instance.client.from('${table}').select().order(${orderArgs});\n      yield data;\n      await Future.delayed(const Duration(seconds: 10));\n    }\n  }();`;
    });
    
    const regex2 = /return\s+Supabase\.instance\.client\s*\.from\('([^']+)'\)\s*\.stream\([^)]+\)\s*\.eq\(([^)]+)\)\s*\.order\(([^)]+)\);/g;
    content = content.replace(regex2, (match, table, eqArgs, orderArgs) => {
        return `return () async* {\n    while (true) {\n      final data = await Supabase.instance.client.from('${table}').select().eq(${eqArgs}).order(${orderArgs});\n      yield data;\n      await Future.delayed(const Duration(seconds: 10));\n    }\n  }();`;
    });
    
    fs.writeFileSync(filePath, content, 'utf8');
  }
}
console.log('Done.');
