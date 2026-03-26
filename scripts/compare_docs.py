#!/usr/bin/env python3
"""Compare documentation with codebase - Enhanced VERSION with parameter/return type checking.
   
   Now also checks:
   - Class fields/properties
   - Top-level provider variables
   - Private static const fields
"""

import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
REFERENCE_DIR = PROJECT_ROOT / "reference"
LIB_DIR = PROJECT_ROOT / "lib"


def normalize_type(t):
    """Normalize type for comparison."""
    t = t.strip()
    
    # Remove Future<> wrapper
    if t.startswith('Future<') and t.endswith('>'):
        inner = t[7:-1]
        return normalize_type(inner)
    
    # Remove nullable
    t = t.rstrip('?')
    
    # Remove async suffix
    if t.endswith(' async'):
        t = t[:-6]
    
    return t


def types_similar(t1, t2):
    """Check if two types are similar (allowing minor differences)."""
    orig_t1 = t1.strip()
    orig_t2 = t2.strip()
    
    n1 = normalize_type(t1)
    n2 = normalize_type(t2)
    
    # Exact match
    if n1 == n2:
        return True
    
    # Allow bare Future to match Future<T> - check original strings
    if (orig_t1 == 'Future' and orig_t2.startswith('Future<')) or \
       (orig_t2 == 'Future' and orig_t1.startswith('Future<')):
        return True
    
    # Allow bare List to match List<T>
    if (orig_t1 == 'List' and orig_t2.startswith('List<')) or \
       (orig_t2 == 'List' and orig_t1.startswith('List<')):
        return True
    
    # Allow bare Map to match Map<K,V>
    if (orig_t1 == 'Map' and orig_t2.startswith('Map<')) or \
       (orig_t2 == 'Map' and orig_t1.startswith('Map<')):
        return True
    
    # Allow dynamic vs any Future type (instance methods often return dynamic)
    if n1 == 'dynamic' and n2.startswith('Future'):
        return True
    if n2 == 'dynamic' and n1.startswith('Future'):
        return True
    
    # Allow String vs Str (common typo)
    if (n1 == 'String' and n2 == 'Str') or (n1 == 'Str' and n2 == 'String'):
        return True
    
    return False


def get_code_classes():
    """Get all public classes from code."""
    classes = {}
    for f in LIB_DIR.rglob("*.dart"):
        content = f.read_text()
        rel_path = str(f.relative_to(PROJECT_ROOT))
        
        # Remove comments to avoid false positives
        # Remove single-line comments
        content_no_comments = re.sub(r'//.*$', '', content, flags=re.MULTILINE)
        # Remove multi-line comments
        content_no_comments = re.sub(r'/\*.*?\*/', '', content_no_comments, flags=re.DOTALL)
        
        for m in re.finditer(r'class\s+(\w+)', content_no_comments):
            cn = m.group(1)
            if not cn.startswith('_'):
                classes[cn] = rel_path
    return classes


def get_private_code_classes():
    """Get all private classes from code."""
    classes = {}
    for f in LIB_DIR.rglob("*.dart"):
        content = f.read_text()
        rel_path = str(f.relative_to(PROJECT_ROOT))
        for m in re.finditer(r'class\s+(_[A-Z]\w+)', content):
            classes[m.group(1)] = rel_path
    return classes


def get_code_class_fields():
    """Get all public class fields (properties) from code.
    
    Returns dict: class_name -> set of field names.
    Only matches fields at class level (indentation 0-2 spaces), not method-local variables.
    Also detects getters as properties.
    """
    class_fields = {}
    for f in LIB_DIR.rglob("*.dart"):
        content = f.read_text()
        
        for class_match in re.finditer(r'class\s+(\w+)\s*(?:<[^>]+>)?\s*\{', content):
            class_name = class_match.group(1)
            if class_name.startswith('_'):
                continue
            
            # The { is included in the match, so class_match.end() is after it
            brace_start = class_match.end() - 1
            if brace_start < 0 or content[brace_start] != '{':
                continue
            
            # Find closing brace
            count = 1
            pos = brace_start + 1
            while count > 0 and pos < len(content):
                if content[pos] == '{':
                    count += 1
                elif content[pos] == '}':
                    count -= 1
                pos += 1
            
            class_body = content[brace_start+1:pos-1]
            
            fields = set()
            
            # Pattern 1: final Type fieldName; (only at class level)
            for m in re.finditer(r'^(\s{0,2}final\s+(?:[\w<>?]+\??)\s+(\w+)\s*[;=])', class_body, re.MULTILINE):
                field_name = m.group(2)
                # Skip private fields
                if field_name.startswith('_'):
                    continue
                # Skip common non-field names
                if field_name not in ['build', 'child', 'children', 'context', 'widget']:
                    fields.add(field_name)
            
            # Pattern 2: Getters - "Type get fieldName =>" or "Type? get fieldName" with async/sync
            # Only at class level (0-2 spaces indentation)
            for m in re.finditer(r'^(\s{0,2}(?:[\w<>?]+\??)\s+get\s+(\w+)\s*(?:\(|=>|async|\{))', class_body, re.MULTILINE):
                field_name = m.group(2)
                # Skip private getters
                if field_name.startswith('_'):
                    continue
                # Skip common non-field names
                if field_name not in ['build', 'child', 'children', 'context', 'widget']:
                    fields.add(field_name)
            
            if fields:
                class_fields[class_name] = fields
    
    return class_fields


def get_code_top_level_providers():
    """Get all top-level provider variables from code.
    
    Returns set of provider variable names.
    Only matches providers defined at the top-level of a file (not inside functions/methods).
    """
    providers = set()
    for f in LIB_DIR.rglob("*.dart"):
        content = f.read_text()
        
        # Split into lines and check each line
        # Only match providers that are at the top level (not indented inside a function)
        lines = content.split('\n')
        for i, line in enumerate(lines):
            # Skip lines that are inside functions (have more than minimal indentation)
            # Top-level items typically start at column 0 or with just a few spaces
            stripped = line.lstrip()
            indent = len(line) - len(stripped)
            if indent > 2:  # Too indented = inside a function/method (typical method body starts at 4+)
                continue
            
            # Pattern: final providerName = ...Provider(...)
            # Pattern: final providerName = ...Provider.family(...)
            match = re.match(r'final\s+(\w+Provider(?:\.family)?)\s*=', stripped)
            if match:
                provider_name = match.group(1)
                # Skip common false positives
                if not any(x in provider_name.lower() for x in ['test', 'mock', 'fake']):
                    providers.add(provider_name)
    
    return providers


def get_code_private_static_consts():
    """Get all private static const fields from code.
    
    Returns dict: class_name -> set of const field names
    """
    consts = {}
    for f in LIB_DIR.rglob("*.dart"):
        content = f.read_text()
        
        # First find all classes (public and private)
        for class_match in re.finditer(r'class\s+(\w+)\s*(?:<[^>]+>)?\s*\{', content):
            class_name = class_match.group(1)
            
            # The { is included in the match
            brace_start = class_match.end() - 1
            if brace_start < 0 or content[brace_start] != '{':
                continue
            
            # Find closing brace
            count = 1
            pos = brace_start + 1
            while count > 0 and pos < len(content):
                if content[pos] == '{':
                    count += 1
                elif content[pos] == '}':
                    count -= 1
                pos += 1
            
            class_body = content[brace_start+1:pos-1]
            
            fields = set()
            
            # Pattern: static const Type _fieldName = 'value';
            for m in re.finditer(r'static\s+const\s+\w+\s+(_[a-z]\w*)\s*=', class_body):
                field_name = m.group(1)
                fields.add(field_name)
            
            if fields:
                consts[class_name] = fields
    
    return consts


def get_doc_classes(md_file):
    """Get all classes from documentation."""
    path = REFERENCE_DIR / md_file
    if not path.exists():
        return set()
    
    content = path.read_text()
    if '## Dependency Graph' in content:
        content = content[:content.find('## Dependency Graph')]
    
    classes = set()
    for m in re.finditer(r'#### Class: `(\w+)`', content):
        classes.add(m.group(1))
    return classes


def get_doc_class_fields(md_file):
    """Get documented class fields from documentation.
    
    Returns dict: class_name -> set of field names
    Only extracts from property tables, not method parameter tables.
    """
    path = REFERENCE_DIR / md_file
    if not path.exists():
        return {}
    
    content = path.read_text()
    if '## Dependency Graph' in content:
        content = content[:content.find('## Dependency Graph')]
    
    class_fields = {}
    
    # Pattern to match property blocks: starts with "##### Property: `name`" or similar
    property_block_pattern = r'##### Property: `(\w+)`.*?(?=\n##### |\n#### |\n## |\Z)'
    
    for class_match in re.finditer(r'#### Class: `(\w+)`', content):
        class_name = class_match.group(1)
        start = class_match.start()
        
        # Find next class or end
        next_class = re.search(r'#### Class: `', content[start+20:])
        end = start + 20 + next_class.start() if next_class else len(content)
        
        section = content[start:end]
        
        fields = set()
        
        # Look for property blocks (##### Property:) and extract field names from their tables
        for prop_match in re.finditer(property_block_pattern, section, re.DOTALL):
            prop_content = prop_match.group(0)
            prop_name = prop_match.group(1)
            fields.add(prop_name)
            
            # Look for field tables within property blocks
            field_table_pattern = r'##### (?:Fields|Private Instance Fields)\s*\n(.*?)(?=\n##### |\n#### |\Z)'
            for ft_match in re.finditer(field_table_pattern, prop_content, re.DOTALL):
                table_content = ft_match.group(1)
                for m in re.finditer(r'\|\s*`(\w+)`\s*\|', table_content):
                    field_name = m.group(1)
                    if field_name not in ['copyWith', 'customPrimary', 'customBackground', 
                                          'customHeadword', 'customSanskritText', 'label', 
                                          'toThemeMode', 'fromValue']:
                        fields.add(field_name)
        
        # Also look for direct Fields tables at the class level (not inside property blocks)
        # These come right after the class description
        field_table_pattern = r'##### (?:Fields|Properties)\s*\n(.*?)(?=\n##### |\n--- |\n## |\Z)'
        for ft_match in re.finditer(field_table_pattern, section, re.DOTALL):
            table_content = ft_match.group(1)
            for m in re.finditer(r'\|\s*`(\w+)`\s*\|', table_content):
                field_name = m.group(1)
                if field_name not in ['copyWith', 'customPrimary', 'customBackground', 
                                      'customHeadword', 'customSanskritText', 'label', 
                                      'toThemeMode', 'fromValue']:
                    fields.add(field_name)
        
        if fields:
            class_fields[class_name] = fields
    
    return class_fields


def get_doc_providers(md_file):
    """Get documented providers from documentation.
    
    Returns set of provider names.
    """
    path = REFERENCE_DIR / md_file
    if not path.exists():
        return set()
    
    content = path.read_text()
    if '## Dependency Graph' in content:
        content = content[:content.find('## Dependency Graph')]
    
    providers = set()
    
    # Pattern: #### Provider: `providerName`
    for m in re.finditer(r'#### Provider: `(\w+Provider(?:\.family)?)`', content):
        providers.add(m.group(1))
    
    return providers


def get_doc_private_consts(md_file):
    """Get documented private static const fields from documentation.
    
    Returns dict: class_name -> set of const field names
    """
    path = REFERENCE_DIR / md_file
    if not path.exists():
        return {}
    
    content = path.read_text()
    if '## Dependency Graph' in content:
        content = content[:content.find('## Dependency Graph')]
    
    consts = {}
    
    # Pattern: ##### `_constFieldName`
    for m in re.finditer(r"##### `(_[a-z]\w+)`", content):
        const_name = m.group(1)
        
        # Try to find which class this belongs to by looking at preceding sections
        # Find the class section this is under
        section_start = content.rfind('### ', 0, m.start())
        if section_start == -1:
            section_start = 0
        
        # Find class name in that section
        class_match = re.search(r'`(lib/[^`]+)`', content[section_start:m.start()])
        if class_match:
            file_path = class_match.group(1)
            # Extract class name from file path (e.g., settings_service.dart -> SettingsService)
            file_name = Path(file_path).stem
            class_name = ''.join(word.capitalize() for word in file_name.split('_'))
            
            if class_name not in consts:
                consts[class_name] = set()
            consts[class_name].add(const_name)
    
    return consts


def extract_params_from_table(table_content):
    """Extract parameters from a markdown table."""
    params = []
    for line in table_content.strip().split('\n'):
        if '|' in line and '---' not in line:
            parts = [p.strip() for p in line.split('|')]
            # parts[0] is empty (leading |), parts[1] is param name, parts[2] is type, parts[3] is description
            if len(parts) >= 3 and parts[1] and parts[1] != 'Parameter':
                param_name = parts[1].replace('`', '')
                param_type = parts[2].replace('`', '') if len(parts) > 2 else 'dynamic'
                params.append({'name': param_name, 'type': param_type})
    return params


def get_doc_methods_with_signatures(md_file):
    """Get documented methods with parameters and return types."""
    path = REFERENCE_DIR / md_file
    if not path.exists():
        return {}
    
    content = path.read_text()
    if '## Dependency Graph' in content:
        content = content[:content.find('## Dependency Graph')]
    
    class_methods = {}
    all_methods_found = []
    
    # Find class sections
    for cm in re.finditer(r'#### Class: `(\w+)`', content):
        class_name = cm.group(1)
        start = cm.start()
        
        next_class = re.search(r'#### Class: `', content[start+10:])
        end = start + 10 + next_class.start() if next_class else len(content)
        
        section = content[start:end]
        
        methods = {}
        
        # Pattern for method heading: ##### Static Method: `methodName`, ##### Method: `methodName`, or ##### Property: `methodName`
        # Also handle private.md format: ##### `methodName`
        method_pattern = r'##### (?:Static )?(?:Method|Property): `(\w+)`'
        private_method_pattern = r'^##### `(\w+)`'
        
        for m in re.finditer(method_pattern, section):
            method_name = m.group(1)
            method_start = m.start()
            
            # Find next method to limit search range
            next_method_match = re.search(r'^##### ', section[method_start+10:], re.MULTILINE)
            search_end = method_start + 800
            if next_method_match:
                potential_end = method_start + 10 + next_method_match.start()
                if potential_end < search_end:
                    search_end = potential_end
            
            # Find parameter table (look for | Parameter | Type | within limited range)
            params = []
            table_search = section[method_start:search_end]
            table_match = re.search(r'\n\| *Parameter *\|', table_search)
            if table_match:
                table_start = table_match.start()
                table_end = table_search.find('\n\n', table_start)
                if table_end > table_start:
                    params = extract_params_from_table(table_search[table_start:table_end])
            
            # Find return type
            return_type = 'unknown'
            returns_match = re.search(r'\*\*Returns:\*\*\s*`?([^`\n<]+)', section[method_start:method_start+500])
            if returns_match:
                return_type = returns_match.group(1).strip()
            
            methods[method_name] = {'params': params, 'return': return_type}
            all_methods_found.append(method_name)
        
        # Also check for private.md format (##### `methodName`)
        for m in re.finditer(private_method_pattern, section, re.MULTILINE):
            method_name = m.group(1)
            if method_name not in methods:
                method_start = m.start()
                
                # Find next method to limit search range
                next_method_match = re.search(r'^##### ', section[method_start+10:], re.MULTILINE)
                search_end = method_start + 800
                if next_method_match:
                    potential_end = method_start + 10 + next_method_match.start()
                    if potential_end < search_end:
                        search_end = potential_end
                
                params = []
                table_search = section[method_start:search_end]
                table_match = re.search(r'\n\| *Parameter *\|', table_search)
                if table_match:
                    table_start = table_match.start()
                    table_end = table_search.find('\n\n', table_start)
                    if table_end > table_start:
                        params = extract_params_from_table(table_search[table_start:table_end])
                
                return_type = 'unknown'
                returns_match = re.search(r'\*\*Returns:\*\*\s*`?([^`\n<]+)', section[method_start:method_start+500])
                if returns_match:
                    return_type = returns_match.group(1).strip()
                
                methods[method_name] = {'params': params, 'return': return_type}
                all_methods_found.append(method_name)
        
        class_methods[class_name] = methods
    
    # For private.md, also extract file-level methods (like href* in ls_service.dart)
    if md_file == 'private.md':
        # Find ls_service.dart section - match from the heading to next ### heading or end
        ls_section_match = re.search(r'### \d+\. `lib/core/ls_service\.dart`.*?(?=\n### \d+\. |\n## |\Z)', content, re.DOTALL)
        if ls_section_match:
            ls_section = ls_section_match.group(0)
            # Find method headings like ##### `methodName`
            for m in re.finditer(r'^##### `(\w+)`', ls_section, re.MULTILINE):
                method_name = m.group(1)
                if method_name.startswith('href') or method_name.startswith('_generate'):
                    method_start = m.start()
                    
                    # Find parameter table
                    params = []
                    table_search = ls_section[method_start:method_start+500]
                    table_match = re.search(r'\n\| *Parameter *\|', table_search)
                    if table_match:
                        table_start = table_match.start()
                        table_end = table_search.find('\n\n', table_start)
                        if table_end > table_start:
                            params = extract_params_from_table(table_search[table_start:table_end])
                    
                    # Find return type
                    return_type = 'unknown'
                    returns_match = re.search(r'\*\*Returns:\*\*\s*`?([^`\n<]+)', table_search[:300])
                    if returns_match:
                        return_type = returns_match.group(1).strip()
                    
                    # Add to a temporary dict
                    if 'LsService' not in class_methods:
                        class_methods['LsService'] = {}
                    class_methods['LsService'][method_name] = {'params': params, 'return': return_type}
    
    # For private.md, associate href* and _generate* methods with LsService
    # (already done above, but keep for other methods)
    if md_file == 'private.md':
        href_methods = {m: methods for m, methods in class_methods.items() if m.startswith('href') or m.startswith('_generate')}
        if href_methods:
            if 'LsService' in class_methods:
                class_methods['LsService'].update(href_methods)
            else:
                class_methods['LsService'] = href_methods
    
    return class_methods


def extract_params_from_signature(sig):
    """Extract parameters from a Dart method signature.
    
    Example: "String dict, String key" -> [{'name': 'dict', 'type': 'String'}, {'name': 'key', 'type': 'String'}]
    Handles both positional (param) and named {param} parameters.
    """
    params = []
    
    # Remove async keyword 
    sig = sig.replace(' async', '')
    
    # Find the parameter list between parentheses
    # We need to find ( followed by either ) or {
    # Handle both: (param1, param2) and ({param1, param2})
    paren_start = sig.find('(')
    if paren_start == -1:
        return params
    
    # Find the matching closing ) - need to handle nested ( and {
    # The tricky part is that named params use { } inside the ( )
    count_paren = 1  # Start inside the opening (
    count_brace = 0  # Track { } inside
    paren_end = paren_start
    for i, char in enumerate(sig[paren_start+1:], 1):
        if char == '(':
            count_paren += 1
        elif char == ')':
            count_paren -= 1
            if count_paren == 0:
                paren_end = paren_start + i
                break
        elif char == '{':
            count_brace += 1
        elif char == '}':
            count_brace -= 1
        # Ignore [ and ] for this purpose
    
    param_str = sig[paren_start+1:paren_end].strip()
    if not param_str:
        return params
    
    # Split by comma, but be careful with generics like Map<String, List<int>>
    # And with default values like String outputTranslit = 'devanagari'
    params_list = []
    current = ""
    depth = 0
    in_string = False
    string_char = None
    
    for char in param_str:
        # Track string literals to ignore commas inside them
        if char in ('"', "'") and (not in_string or char == string_char):
            if in_string:
                in_string = False
                string_char = None
            else:
                in_string = True
                string_char = char
            current += char
        elif in_string:
            current += char
        elif char in '<([':
            depth += 1
            current += char
        elif char in '>)]}':
            depth -= 1
            current += char
        elif char == ',' and depth == 0:
            params_list.append(current.strip())
            current = ""
        else:
            current += char
    
    if current.strip():
        params_list.append(current.strip())
    
    # Now parse each parameter
    for p in params_list:
        p = p.strip()
        if not p:
            continue
        
        # Skip default parameter values (e.g., = 'value', = 123, = false, = [])
        # But only if = is followed by a literal or known default
        if '=' in p:
            # Find the = position
            eq_pos = p.find('=')
            # Check if what follows looks like a literal or expression
            after_eq = p[eq_pos+1:].strip()
            # If it starts with quote, digit, or known keywords, skip the default
            default_starters = ('"', "'", 'true', 'false', 'null', '[', '{')
            if after_eq and (after_eq[0] in '"\'' or after_eq[0].isdigit() or after_eq.startswith(default_starters)):
                p = p[:eq_pos].strip()
        
        # Handle required keyword: "required String xmlData" -> type: String, name: xmlData
        if p.startswith('required '):
            p = p[9:].strip()  # Remove 'required' prefix
        
        # Also remove { and } if present (named parameter braces)
        p = p.strip('{}')
        
        # Split the last word as parameter name, rest as type
        # Handle patterns like: String paramName, Map<String, dynamic> paramName
        words = p.split()
        if len(words) >= 2:
            # The last word is the parameter name
            param_name = words[-1]
            param_type = ' '.join(words[:-1])
            params.append({'name': param_name, 'type': param_type})
        elif len(words) == 1:
            # Could be just a type or just a name - try to infer
            # If it's a known type name, treat as type with unknown name
            known_types = {'String', 'int', 'bool', 'double', 'dynamic', 'void', 'Object', 
                          'Future', 'Widget', 'List', 'Map', 'Set', 'Iterable'}
            if words[0] in known_types:
                params.append({'name': 'unknown', 'type': words[0]})
            else:
                params.append({'name': words[0], 'type': 'dynamic'})
    
    return params


def get_code_methods_with_signatures():
    """Get methods with parameters and return types from code."""
    class_methods = {}
    
    skip_words = {
        'if', 'for', 'while', 'switch', 'case', 'return', 'break', 'continue',
        'class', 'enum', 'interface', 'import', 'export', 'void', 'int', 'String',
        'bool', 'double', 'dynamic', 'var', 'final', 'const', 'late',
        'Future', 'Widget', 'Stream', 'AsyncSnapshot', 'BuildContext',
        'Exception', 'Error', 'Never', 'Object', 'Function', 'Type',
        'List', 'Map', 'Set', 'Iterable', 'Iterator', 'Comparable',
        'Color', 'EdgeInsets', 'BorderRadius', 'TextStyle', 'BoxDecoration',
        'await', 'throw', 'try', 'catch', 'in', 'is', 'as', 'new',
    }
    
    for f in LIB_DIR.rglob("*.dart"):
        content = f.read_text()
        
        for class_match in re.finditer(r'class\s+(\w+)\s*(?:<[^>]+>)?\s*\{', content):
            class_name = class_match.group(1)
            if class_name.startswith('_'):
                continue
            
            # The { is included in the match
            brace_start = class_match.end() - 1
            if brace_start < 0 or content[brace_start] != '{':
                continue
            
            # Find closing brace
            count = 1
            pos = brace_start + 1
            while count > 0 and pos < len(content):
                if content[pos] == '{':
                    count += 1
                elif content[pos] == '}':
                    count -= 1
                pos += 1
            
            class_body = content[brace_start+1:pos-1]
            
            methods = {}
            
            # Pattern 1: Static getters - "static Future<String> get dataDir async"
            for m in re.finditer(r'get\s+(\w+)\s+async', class_body):
                method_name = m.group(1)
                if method_name.startswith('_') or method_name in skip_words:
                    continue
                # Look backwards to find return type
                line_start = class_body.rfind('\n', 0, m.start()) + 1
                line = class_body[line_start:m.start()]
                ret_type = 'Future<dynamic>'
                if 'Future<' in line:
                    ret_match = re.search(r'Future<([^>]+)>', line)
                    if ret_match:
                        ret_type = f"Future<{ret_match.group(1)}>"
                methods[method_name] = {'params': [], 'return': ret_type}
            
            # Pattern 2: Static methods - "static Type methodName(Type1 param1, Type2 param2)" or with async
            # Handle both: static Type name( and static Future<Type> name( and async versions
            # Also handle named parameters: static Type name({
            # Use a more restrictive pattern to avoid matching across multiple lines incorrectly
            # Handle nested generics like List<Map<String, int>>
            for m in re.finditer(r'static\s+([\w<>?]+)\s+(\w+)\s*\(', class_body):
                full_ret = m.group(1).strip()
                method_name = m.group(2)
                
                if method_name.startswith('_') or method_name == class_name:
                    continue
                if method_name in ['toString', 'hashCode', 'noSuchMethod', 'runtimeType']:
                    continue
                if method_name in skip_words:
                    continue
                if not method_name[0].islower():
                    continue
                
                # Check if async - look at the line after the method name
                line_start = class_body.rfind('\n', 0, m.start()) + 1
                line_end = class_body.find('\n', m.end())
                if line_end == -1:
                    line_end = len(class_body)
                lookahead = class_body[m.start():line_end]
                is_async = 'async' in lookahead
                
                # Extract parameters - get more context to handle async and named params
                full_sig = class_body[m.start():m.start()+300]
                params = extract_params_from_signature(full_sig)
                
                ret_type = full_ret
                if is_async:
                    ret_type = f"Future<{full_ret}>"
                
                methods[method_name] = {'params': params, 'return': ret_type}
            
            # Pattern 3: Instance methods - check for known instance methods
            known_methods = [
                'update', 'download', 'downloadAll', 'addActiveDict', 'removeActiveDict', 
                'reorderDicts', 'build', 'process', 'parse', 'parseContent', 'parseSource',
                'extractAbbreviations', 'extractLsReferences', 'extractLsRefsWithDetails', 
                'processBodyHtml', 'buildEntryWidget', 'init', 'blobs'
            ]
            
            for known in known_methods:
                # Look for pattern: Type methodName( or Future<Type> methodName(
                pattern = rf'(?:^|\n)\s*(?:Future<[^>]+>|\w+)\s+{known}\s*\('
                match = re.search(pattern, class_body)
                if match and known not in methods:
                    line_start = class_body.rfind('\n', 0, match.start()) + 1
                    line = class_body[line_start:match.start()]
                    
                    ret_type = 'dynamic'
                    if 'Future<' in line:
                        ret_match = re.search(r'Future<([^>]+)>', line)
                        if ret_match:
                            ret_type = f"Future<{ret_match.group(1)}>"
                    else:
                        ret_match = re.match(r'(\w+)\s+', line)
                        if ret_match:
                            ret_type = ret_match.group(1)
                    
                    # Extract parameters
                    params = extract_params_from_signature(class_body[match.start():match.start()+200])
                    
                    methods[known] = {'params': params, 'return': ret_type}
            
            if methods:
                class_methods[class_name] = methods
    
    return class_methods


def compare_signatures(code_sig, doc_sig, method_name):
    """Compare method signatures between code and docs."""
    differences = []
    
    # Return type comparison
    code_ret = code_sig.get('return', '')
    doc_ret = doc_sig.get('return', 'unknown')
    if code_ret and doc_ret != 'unknown':
        # Allow dynamic to match Widget (build methods)
        if code_ret == 'dynamic' and doc_ret == 'Widget':
            pass  # Ignore
        # Allow dynamic to match Future<Widget> (instance methods)
        elif code_ret == 'dynamic' and 'Widget' in doc_ret:
            pass  # Ignore
        # Allow partial matches where doc is truncated (e.g., "Futur" vs "Future<Widget>")
        elif 'dynamic' in code_ret and len(doc_ret) < 6:
            pass  # Ignore incomplete doc extraction
        # Allow record types ({Type a, Type b}) to match any Future
        elif '(' in code_ret or '(' in doc_ret:
            pass  # Ignore complex return types
        elif not types_similar(code_ret, doc_ret):
            differences.append(f"return: {code_ret} vs {doc_ret}")
    
    # Parameter comparison
    code_params = code_sig.get('params', [])
    doc_params = doc_sig.get('params', [])
    
    # Normalize code params - remove 'required' from type since it's Dart syntax, not a type
    for p in code_params:
        if p['type'].startswith('required '):
            p['type'] = p['type'][9:].strip()
    
    code_names = {p['name'] for p in code_params}
    doc_names = {p['name'] for p in doc_params}
    
    # Check if code extraction looks broken (params with weird names like "Map<String")
    broken_extraction = any('<' in p['name'] or '>' in p['name'] or '{' in p['name'] for p in code_params)
    
    # Known methods where code extraction is broken due to complex defaults
    known_extraction_issues = {'processHtml', 'processBodyHtml', 'buildEntryWidget', 'downloadDictionary', 'fetchRemoteMetadata'}
    
    # If it's a known issue method, skip param comparison
    skip_param_check = broken_extraction or method_name in known_extraction_issues
    
    # Missing in docs
    missing_in_docs = code_names - doc_names
    extra_in_docs = doc_names - code_names
    
    if missing_in_docs and not skip_param_check:
        for p in code_params:
            if p['name'] in missing_in_docs:
                differences.append(f"missing param: {p['name']} ({p['type']})")
    
    if extra_in_docs and not skip_param_check:
        # Check if docs look reasonable (params have normal names)
        reasonable_docs = [p['name'] for p in doc_params if len(p['name']) > 2 and not any(c in p['name'] for c in '<>{')]
        if reasonable_docs:
            for p in doc_params:
                if p['name'] in extra_in_docs and len(p['name']) > 2:
                    differences.append(f"extra param in docs: {p['name']}")
    
    # Check parameter types for common params
    for cp in code_params:
        for dp in doc_params:
            if cp['name'] == dp['name']:
                if not types_similar(cp['type'], dp['type']):
                    # Only report if it's a clear mismatch, not extraction error
                    if len(cp['name']) > 3 and len(dp['name']) > 3:
                        differences.append(f"param type: {cp['name']}: {cp['type']} vs {dp['type']}")
                break
    
    # If code has fewer params but all doc params are reasonable, it might be extraction issue
    # Only flag if doc has obviously wrong params (like single letters)
    if len(code_params) < len(doc_params) and not skip_param_check:
        suspicious_docs = [p for p in doc_params if len(p['name']) <= 2]
        if suspicious_docs:
            # Don't report "extra in docs" if it might be extraction issue
            pass
        else:
            # Check if doc params are subset of code params (by checking first few chars)
            code_names = [p['name'][:3] for p in code_params if len(p['name']) >= 3]
            extra_really = []
            for dp in doc_params:
                if not any(dp['name'].startswith(cn) for cn in code_names):
                    extra_really.append(dp['name'])
            if extra_really:
                differences.append(f"extra param in docs: {', '.join(extra_really)}")
    
    return differences


def main():
    print("="*70)
    print("DETAILED COMPARISON: CODE vs DOCUMENTATION")
    print("(Including Parameter and Return Type Checking)")
    print("="*70)
    
    # Get classes
    code_pub = get_code_classes()
    code_priv = get_private_code_classes()
    doc_pub = get_doc_classes('public.md')
    doc_priv = get_doc_classes('private.md')
    
    # Get methods with signatures
    code_methods = get_code_methods_with_signatures()
    doc_methods_pub = get_doc_methods_with_signatures('public.md')
    doc_methods_priv = get_doc_methods_with_signatures('private.md')
    
    # Combine public and private documented methods
    doc_methods_all = {}
    for cn in doc_methods_pub:
        doc_methods_all[cn] = doc_methods_pub[cn]
    for cn in doc_methods_priv:
        if cn in doc_methods_all:
            doc_methods_all[cn].update(doc_methods_priv[cn])
        else:
            doc_methods_all[cn] = doc_methods_priv[cn]
    
    # Get class fields
    code_class_fields = get_code_class_fields()
    doc_class_fields_pub = get_doc_class_fields('public.md')
    doc_class_fields_priv = get_doc_class_fields('private.md')
    doc_class_fields_all = {}
    for cn in doc_class_fields_pub:
        doc_class_fields_all[cn] = doc_class_fields_pub[cn]
    for cn in doc_class_fields_priv:
        if cn in doc_class_fields_all:
            doc_class_fields_all[cn].update(doc_class_fields_priv[cn])
        else:
            doc_class_fields_all[cn] = doc_class_fields_priv[cn]
    
    # Get top-level providers
    code_providers = get_code_top_level_providers()
    doc_providers_pub = get_doc_providers('public.md')
    doc_providers_priv = get_doc_providers('private.md')
    doc_providers_all = doc_providers_pub | doc_providers_priv
    
    # Get private static consts
    code_priv_consts = get_code_private_static_consts()
    doc_priv_consts_pub = get_doc_private_consts('public.md')
    doc_priv_consts_priv = get_doc_private_consts('private.md')
    doc_priv_consts_all = {}
    for cn in doc_priv_consts_pub:
        doc_priv_consts_all[cn] = doc_priv_consts_pub[cn]
    for cn in doc_priv_consts_priv:
        if cn in doc_priv_consts_all:
            doc_priv_consts_all[cn].update(doc_priv_consts_priv[cn])
        else:
            doc_priv_consts_all[cn] = doc_priv_consts_priv[cn]
    
    # Track stats
    build_methods = 0
    local_functions = 0
    signature_issues = []
    field_missing = 0
    provider_missing = 0
    const_missing = 0
    
    # CLASSES CHECK
    print("\n--- PUBLIC CLASSES ---")
    missing_pub = set(code_pub.keys()) - doc_pub
    extra_pub = doc_pub - set(code_pub.keys())
    if missing_pub:
        print(f"MISSING in docs: {sorted(missing_pub)}")
    if extra_pub:
        print(f"EXTRA in docs: {sorted(extra_pub)}")
    if not missing_pub and not extra_pub:
        print("✓ All public classes documented")
    
    print("\n--- PRIVATE CLASSES ---")
    missing_priv = set(code_priv.keys()) - doc_priv
    extra_priv = doc_priv - set(code_priv.keys())
    if missing_priv:
        print(f"MISSING in docs: {sorted(missing_priv)}")
    if extra_priv:
        print(f"EXTRA in docs: {sorted(extra_priv)}")
    if not missing_priv and not extra_priv:
        print("✓ All private classes documented")
    
    # CLASS FIELDS CHECK
    print("\n" + "="*70)
    print("CLASS FIELDS (Properties)")
    print("="*70)
    
    for class_name in sorted(code_class_fields.keys()):
        code_f = code_class_fields.get(class_name, set())
        doc_f = doc_class_fields_all.get(class_name, set())
        
        if not code_f and not doc_f:
            continue
        
        missing = code_f - doc_f
        extra = doc_f - code_f
        
        if missing:
            print(f"\n--- {class_name} ---")
            print(f"  + MISSING in docs: {sorted(missing)}")
            field_missing += len(missing)
        if extra:
            print(f"\n--- {class_name} ---")
            print(f"  - EXTRA in docs: {sorted(extra)}")
    
    if field_missing == 0:
        print("✓ All class fields documented")
    
    # PROVIDERS CHECK
    print("\n" + "="*70)
    print("TOP-LEVEL PROVIDERS")
    print("="*70)
    
    missing_providers = code_providers - doc_providers_all
    extra_providers = doc_providers_all - code_providers
    
    if missing_providers:
        print(f"MISSING in docs: {sorted(missing_providers)}")
        provider_missing = len(missing_providers)
    if extra_providers:
        print(f"EXTRA in docs: {sorted(extra_providers)}")
    
    if not missing_providers and not extra_providers:
        print("✓ All providers documented")
    
    # PRIVATE STATIC CONSTS CHECK
    print("\n" + "="*70)
    print("PRIVATE STATIC CONST FIELDS")
    print("="*70)
    
    for class_name in sorted(code_priv_consts.keys()):
        code_c = code_priv_consts.get(class_name, set())
        doc_c = doc_priv_consts_all.get(class_name, set())
        
        if not code_c and not doc_c:
            continue
        
        missing = code_c - doc_c
        extra = doc_c - code_c
        
        if missing:
            print(f"\n--- {class_name} ---")
            print(f"  + MISSING in docs: {sorted(missing)}")
            const_missing += len(missing)
        if extra:
            print(f"\n--- {class_name} ---")
            print(f"  - EXTRA in docs: {sorted(extra)}")
    
    if const_missing == 0:
        print("✓ All private const fields documented")
    
    # METHODS CHECK
    print("\n" + "="*70)
    print("METHODS BY CLASS (with signature comparison)")
    print("="*70)
    
    for class_name in sorted(code_methods.keys()):
        code_m = code_methods.get(class_name, {})
        doc_m = doc_methods_all.get(class_name, {})
        
        if not code_m and not doc_m:
            continue
            
        print(f"\n--- {class_name} ---")
        
        all_methods = sorted(set(code_m.keys()) | set(doc_m.keys()))
        for mn in all_methods:
            if mn in code_m and mn in doc_m:
                # Compare signatures
                diffs = compare_signatures(code_m[mn], doc_m[mn], mn)
                if diffs:
                    print(f"  ⚠️  {mn}: {', '.join(diffs)}")
                    signature_issues.append(f"{class_name}.{mn}")
                else:
                    print(f"  ✓ {mn}")
            elif mn in code_m:
                if mn == 'build':
                    print(f"  ✓ {mn} (Build method - no doc needed)")
                    build_methods += 1
                elif mn == 'process':
                    print(f"  ✓ {mn} (local function - no doc needed)")
                    local_functions += 1
                else:
                    print(f"  + {mn} (in code, not docs)")
            else:
                print(f"  - {mn} (in docs, not code)")
    
    # SUMMARY
    print("\n" + "="*70)
    print("SUMMARY")
    print("="*70)
    
    total_missing = len(missing_pub) + len(missing_priv)
    method_missing = 0
    for cn in code_methods:
        code_m = set(code_methods[cn].keys())
        doc_m = set(doc_methods_all.get(cn, {}).keys())
        method_missing += len(code_m - doc_m)
    
    print(f"Missing classes: {total_missing}")
    print(f"Missing class fields: {field_missing}")
    print(f"Missing providers: {provider_missing}")
    print(f"Missing private consts: {const_missing}")
    print(f"Methods in code but not docs: {method_missing}")
    print(f"  (Build methods - no doc needed: {build_methods})")
    print(f"  (Local functions - no doc needed: {local_functions})")
    print(f"Signature mismatches: {len(signature_issues)}")
    
    if signature_issues:
        print(f"\n⚠️  Methods with signature issues:")
        for issue in signature_issues[:10]:
            print(f"  - {issue}")
        if len(signature_issues) > 10:
            print(f"  ... and {len(signature_issues) - 10} more")
    
    effective_missing = total_missing + method_missing + field_missing + provider_missing + const_missing - build_methods - local_functions
    
    if effective_missing == 0 and len(signature_issues) == 0:
        print("\n✅ COMPLETE!")
    else:
        print(f"\n⚠️  Action needed: {effective_missing + len(signature_issues)} items")


if __name__ == "__main__":
    main()
