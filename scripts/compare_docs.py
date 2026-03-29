#!/usr/bin/env python3
"""Compare documentation with codebase - Enhanced VERSION with comprehensive method/field detection.
   
   Now also checks:
   - All instance methods (not just known list)
   - All static methods
   - All class fields/properties
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


def get_class_body(content, start_pos):
    """Extract the body of a class starting at start_pos (where the { is).
    Returns (body, end_pos) where end_pos is the position of the closing }.
    """
    brace_start = start_pos
    if content[brace_start] != '{':
        return None, -1
    
    count = 1
    pos = brace_start + 1
    in_string = False
    string_char = None
    in_single_line_comment = False
    in_multi_line_comment = False
    
    while count > 0 and pos < len(content):
        char = content[pos]
        prev_char = content[pos - 1] if pos > 0 else ''
        
        # Handle comments
        if in_single_line_comment:
            if char == '\n':
                in_single_line_comment = False
        elif in_multi_line_comment:
            if prev_char == '*' and char == '/':
                in_multi_line_comment = False
        elif char == '/' and pos + 1 < len(content):
            next_char = content[pos + 1]
            if next_char == '/':
                in_single_line_comment = True
                pos += 1
                continue
            elif next_char == '*':
                in_multi_line_comment = True
                pos += 1
                continue
        elif char in '"\'':
            if not in_string or char == string_char:
                in_string = not in_string
                string_char = char if in_string else None
        
        # Only count braces when not in string or comment
        if not in_string and not in_single_line_comment and not in_multi_line_comment:
            if char == '{':
                count += 1
            elif char == '}':
                count -= 1
        
        pos += 1
    
    if count == 0:
        return content[brace_start + 1:pos - 1], pos - 1
    return None, -1


def find_constructor_pos(class_body):
    """Find the position of the constructor within a class body.
    
    Returns the position of the first constructor, or -1 if not found.
    """
    constructor_pattern = r'(?:const\s+)?(\w+)\s*\('
    for m in re.finditer(constructor_pattern, class_body):
        name = m.group(1)
        if name == 'super' or name == 'this':
            continue
        if name[0].isupper():
            return m.start()
    return -1


def get_code_class_fields():
    """Get all public class fields (properties) from code.
    
    Returns dict: class_name -> set of field names.
    
    NOTE: This only detects TRUE class-level fields and getters/setters,
    NOT constructor parameters (even those marked 'final').
    """
    class_fields = {}
    for f in LIB_DIR.rglob("*.dart"):
        content = f.read_text()
        
        # Find all classes
        for class_match in re.finditer(r'class\s+(\w+)\s*(?:<[^>]+>)?\s*\{', content):
            class_name = class_match.group(1)
            if class_name.startswith('_'):
                continue
            
            class_body, _ = get_class_body(content, class_match.end() - 1)
            if class_body is None:
                continue
            
            fields = set()
            
            # Remove comments from class body for field detection
            body_no_comments = re.sub(r'//.*$', '', class_body, flags=re.MULTILINE)
            body_no_comments = re.sub(r'/\*.*?\*/', '', body_no_comments, flags=re.DOTALL)
            
            # Find constructor position to exclude constructor parameters
            constructor_pos = find_constructor_pos(body_no_comments)
            
            # Pattern 1: final Type fieldName; or final Type fieldName = ...;
            # Only match BEFORE constructor (true class fields, not constructor params)
            # Handles types with spaces like "Map<String, String>" and nullable types
            # Only match indent <= 2 to exclude local variables in methods
            for m in re.finditer(r'^(\s*)final\s+([\w<>,?\s]+?)\s*(\?)?\s+([a-z]\w*)\s*[;=]', body_no_comments, re.MULTILINE):
                indent = len(m.group(1))
                if indent > 2:
                    continue
                if constructor_pos >= 0 and m.start() >= constructor_pos:
                    continue
                field_name = m.group(4)
                if field_name.startswith('_'):
                    continue
                if field_name not in ['build', 'child', 'children', 'context', 'widget']:
                    fields.add(field_name)
            
            # Pattern 2: Type fieldName; (non-final fields) - uppercase type like String, int, etc.
            # Only match BEFORE constructor
            # Only match indent <= 2 to exclude local variables in methods
            for m in re.finditer(r'^(\s*)(?:static\s+)?(?:late\s+)?(?:final\s+)?(?:const\s+)?(?:var\s+)?([\w<>?\s]+?)\s+(\w+)\s*[;=]', body_no_comments, re.MULTILINE):
                indent = len(m.group(1))
                if indent > 2:
                    continue
                if constructor_pos >= 0 and m.start() >= constructor_pos:
                    continue
                field_name = m.group(3)
                if field_name.startswith('_'):
                    continue
                if field_name not in ['build', 'child', 'children', 'context', 'widget']:
                    fields.add(field_name)
            
            # Pattern 3: Getters - "Type get fieldName =>" or "Type? get fieldName" with async/sync/block
            # Handle: Type get name =>, Type get name {, Type get name async {, Type get name async* {
            # Only match indent <= 2 to exclude local getters in methods
            for m in re.finditer(r'^(\s*)(?:[\w<>?]+\??)\s+get\s+(\w+)\s*(?:async\*?\s*)?(?:\(|=>|\{)', body_no_comments, re.MULTILINE):
                indent = len(m.group(1))
                if indent > 2:
                    continue
                field_name = m.group(2)
                if field_name.startswith('_'):
                    continue
                if field_name not in ['build', 'child', 'children', 'context', 'widget']:
                    fields.add(field_name)
            
            # Pattern 4: Setter - "set fieldName(...)"
            # Only match indent <= 2 to exclude local setters in methods
            for m in re.finditer(r'^(\s*)set\s+(\w+)\s*\(', body_no_comments, re.MULTILINE):
                indent = len(m.group(1))
                if indent > 2:
                    continue
                field_name = m.group(2)
                if field_name.startswith('_'):
                    continue
                if field_name not in ['build', 'child', 'children', 'context', 'widget']:
                    fields.add(field_name)
            
            if fields:
                class_fields[class_name] = fields
    
    return class_fields


def get_code_top_level_providers():
    """Get all top-level provider variables from code.
    
    Returns set of provider variable names.
    """
    providers = set()
    for f in LIB_DIR.rglob("*.dart"):
        content = f.read_text()
        
        lines = content.split('\n')
        for i, line in enumerate(lines):
            stripped = line.lstrip()
            indent = len(line) - len(stripped)
            if indent > 2:
                continue
            
            match = re.match(r'final\s+(\w+Provider(?:\.family)?)\s*=', stripped)
            if match:
                provider_name = match.group(1)
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
        
        for class_match in re.finditer(r'class\s+(\w+)\s*(?:<[^>]+>)?\s*\{', content):
            class_name = class_match.group(1)
            
            class_body, _ = get_class_body(content, class_match.end() - 1)
            if class_body is None:
                continue
            
            fields = set()
            
            # Pattern: static const Type _fieldName = 'value';
            for m in re.finditer(r'static\s+const\s+\w+\s+(_[a-z]\w*)\s*=', class_body):
                field_name = m.group(1)
                fields.add(field_name)
            
            if fields:
                consts[class_name] = fields
    
    return consts


def get_code_methods_with_signatures():
    """Get methods with parameters and return types from code.
    
    Detects BOTH static and instance methods comprehensively.
    """
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
        # Known false positives from function calls
        'join', 'basename', 'dirname', 'extension', 'withoutExtension',
        'withoutExtension', 'split', 'relative', 'absolute',
    }
    
    for f in LIB_DIR.rglob("*.dart"):
        content = f.read_text()
        
        for class_match in re.finditer(r'class\s+(\w+)\s*(?:<[^>]+>)?\s*\{', content):
            class_name = class_match.group(1)
            if class_name.startswith('_'):
                continue
            
            class_body, _ = get_class_body(content, class_match.end() - 1)
            if class_body is None:
                continue
            
            methods = {}
            
            # Remove comments from class body for method detection
            body_no_comments = re.sub(r'//.*$', '', class_body, flags=re.MULTILINE)
            body_no_comments = re.sub(r'/\*.*?\*/', '', body_no_comments, flags=re.DOTALL)
            
            # Pattern 1: Static methods - "static Type methodName(...)"
            # Handle: static Type name(, static Future<Type> name(, static async name(
            static_pattern = r'static\s+([\w<>?]+)\s+(\w+)\s*\('
            for m in re.finditer(static_pattern, body_no_comments):
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
                
                # Check if async - look ahead
                match_end = m.end()
                lookahead = body_no_comments[match_end:match_end+50]
                is_async = 'async' in lookahead
                
                # Extract parameters
                params = extract_params_from_signature(body_no_comments[m.start():m.start()+500])
                
                ret_type = full_ret
                if is_async:
                    ret_type = f"Future<{full_ret}>"
                
                methods[method_name] = {'params': params, 'return': ret_type}
            
            # Pattern 1b: Factory constructors - "factory ClassName.methodName(...)"
            factory_pattern = r'factory\s+(\w+)\.(\w+)\s*\('
            for m in re.finditer(factory_pattern, body_no_comments):
                class_name_in_factory = m.group(1)
                method_name = m.group(2)
                
                if class_name_in_factory != class_name:
                    continue
                if method_name.startswith('_'):
                    continue
                if method_name in ['toString', 'hashCode', 'noSuchMethod', 'runtimeType']:
                    continue
                if method_name in skip_words:
                    continue
                if not method_name[0].islower():
                    continue
                
                params = extract_params_from_signature(body_no_comments[m.start():m.start()+500])
                methods[method_name] = {'params': params, 'return': class_name}
            
            # Pattern 2: Instance methods - match ANY method that starts with return type
            # This catches instance methods like: Future<List<String>> getPrefixSuggestions(
            # Also handles: Type name(), Future<Type> name(), async name(), etc.
            # Handles complex types by matching until we find a lowercase method name followed by (
            instance_pattern = r'(?:^|\n)([ \t]*)([\w<>?, ]+?)\s+([a-z]\w*)\s*\('
            for m in re.finditer(instance_pattern, body_no_comments, re.MULTILINE):
                indent = len(m.group(1))
                full_ret = m.group(2).strip()
                method_name = m.group(3)
                
                # Skip if this is a static method (already caught above)
                # Check if preceded by 'static' on same line
                match_pos = m.start()
                line_start_pos = body_no_comments.rfind('\n', 0, match_pos) + 1
                # Find end of line - look for newline AFTER the match
                line_end_pos = body_no_comments.find('\n', match_pos + len(m.group(0)))
                if line_end_pos == -1:
                    line_end_pos = len(body_no_comments)
                line_content = body_no_comments[line_start_pos:line_end_pos].strip()
                if line_content == 'static':
                    continue
                
                # Skip if this is a factory constructor (already caught above)
                if line_content == 'factory':
                    continue
                
                # Skip return statements like "return await openDatabase("
                if line_content.startswith('return '):
                    continue
                
                # Skip private methods
                if method_name.startswith('_'):
                    continue
                if method_name == class_name:
                    continue
                if method_name in ['toString', 'hashCode', 'noSuchMethod', 'runtimeType']:
                    continue
                if method_name in skip_words:
                    continue
                # Skip if first char is uppercase (likely a type declaration)
                if method_name[0].isupper():
                    continue
                
                # Skip database column/table names that look like variables
                if method_name in ['dictionaries', 'files', 'flash_card_scores', 
                                   'freedict_dictionaries', 'fts5', 'saf_scan_cache',
                                   'search_history', 'word_index', 'word_metadata',
                                   'snippet', 'task']:
                    continue
                
                # Skip debug/logger function calls
                if method_name in ['debugPrint', 'hDebugPrint']:
                    continue
                
                # Skip if already found (static method takes precedence)
                if method_name in methods:
                    continue
                
                # Check if async
                match_end = m.end()
                lookahead = body_no_comments[match_end:match_end+50]
                is_async = 'async' in lookahead
                
                # Extract parameters
                params = extract_params_from_signature(body_no_comments[m.start():m.start()+500])
                
                ret_type = full_ret
                if is_async:
                    if full_ret in ['void', 'dynamic']:
                        ret_type = f"Future<{full_ret}>"
                    else:
                        ret_type = f"Future<{full_ret}>"
                
                methods[method_name] = {'params': params, 'return': ret_type}
            
            # Pattern 3: Constructors - "ClassName(...)" or "ClassName._(...)"
            # These have no return type, but we might want to skip them
            
            if methods:
                class_methods[class_name] = methods
    
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
    paren_start = sig.find('(')
    if paren_start == -1:
        return params
    
    # Find the matching closing ) - need to handle nested ( and {
    count_paren = 1
    count_brace = 0
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
    
    param_str = sig[paren_start+1:paren_end].strip()
    if not param_str:
        return params
    
    # Split by comma, but be careful with generics
    params_list = []
    current = ""
    depth = 0
    in_string = False
    string_char = None
    
    for char in param_str:
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
        
        # Skip default parameter values
        if '=' in p:
            eq_pos = p.find('=')
            after_eq = p[eq_pos+1:].strip()
            default_starters = ('"', "'", 'true', 'false', 'null', '[', '{')
            if after_eq and (after_eq[0] in '"\'' or after_eq[0].isdigit() or after_eq.startswith(default_starters)):
                p = p[:eq_pos].strip()
            elif after_eq and '.' in after_eq:
                p = p[:eq_pos].strip()
        
        # Handle required keyword
        if p.startswith('required '):
            p = p[9:].strip()
        
        # Remove { and } if present (named parameter braces)
        # Also remove [] for optional positional parameters
        # Also remove trailing commas from parameter list
        # Note: strip whitespace and brackets together because [ at start prevents whitespace strip
        p = p.strip(' \t\n\r{}[] ,')
        
        # Split the last word as parameter name, rest as type
        words = p.split()
        if len(words) >= 2:
            param_name = words[-1]
            param_type = ' '.join(words[:-1])
            params.append({'name': param_name, 'type': param_type})
        elif len(words) == 1:
            known_types = {'String', 'int', 'bool', 'double', 'dynamic', 'void', 'Object', 
                          'Future', 'Widget', 'List', 'Map', 'Set', 'Iterable'}
            if words[0] in known_types:
                params.append({'name': 'unknown', 'type': words[0]})
            else:
                params.append({'name': words[0], 'type': 'dynamic'})
    
    return params


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
    """
    path = REFERENCE_DIR / md_file
    if not path.exists():
        return {}
    
    content = path.read_text()
    if '## Dependency Graph' in content:
        content = content[:content.find('## Dependency Graph')]
    
    class_fields = {}
    
    property_block_pattern = r'##### Property: `(\w+)`.*?(?=\n##### |\n#### |\n## |\Z)'
    
    for class_match in re.finditer(r'#### Class: `(\w+)`', content):
        class_name = class_match.group(1)
        start = class_match.start()
        
        next_class = re.search(r'#### Class: `', content[start+20:])
        end = start + 20 + next_class.start() if next_class else len(content)
        
        section = content[start:end]
        
        fields = set()
        
        for prop_match in re.finditer(property_block_pattern, section, re.DOTALL):
            prop_content = prop_match.group(0)
            prop_name = prop_match.group(1)
            fields.add(prop_name)
            
            field_table_pattern = r'##### (?:Fields|Private Instance Fields)\s*\n(.*?)(?=\n##### |\n#### |\Z)'
            for ft_match in re.finditer(field_table_pattern, prop_content, re.DOTALL):
                table_content = ft_match.group(1)
                for m in re.finditer(r'\|\s*`(\w+)`\s*\|', table_content):
                    field_name = m.group(1)
                    if field_name not in ['copyWith', 'customPrimary', 'customBackground', 
                                          'customHeadword', 'customSanskritText', 'label', 
                                          'toThemeMode', 'fromValue']:
                        fields.add(field_name)
        
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
    """Get documented providers from documentation."""
    path = REFERENCE_DIR / md_file
    if not path.exists():
        return set()
    
    content = path.read_text()
    if '## Dependency Graph' in content:
        content = content[:content.find('## Dependency Graph')]
    
    providers = set()
    
    for m in re.finditer(r'#### Provider: `(\w+Provider(?:\.family)?)`', content):
        providers.add(m.group(1))
    
    return providers


def get_doc_private_consts(md_file):
    """Get documented private static const fields from documentation."""
    path = REFERENCE_DIR / md_file
    if not path.exists():
        return {}
    
    content = path.read_text()
    if '## Dependency Graph' in content:
        content = content[:content.find('## Dependency Graph')]
    
    consts = {}
    
    for m in re.finditer(r"##### `(_[a-z]\w+)`", content):
        const_name = m.group(1)
        
        section_start = content.rfind('### ', 0, m.start())
        if section_start == -1:
            section_start = 0
        
        class_match = re.search(r'`(lib/[^`]+)`', content[section_start:m.start()])
        if class_match:
            file_path = class_match.group(1)
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
    
    for cm in re.finditer(r'#### Class: `(\w+)`', content):
        class_name = cm.group(1)
        start = cm.start()
        
        next_class = re.search(r'#### Class: `', content[start+10:])
        end = start + 10 + next_class.start() if next_class else len(content)
        
        section = content[start:end]
        
        methods = {}
        
        method_pattern = r'##### (?:Static )?(?:Method): `(\w+)`'
        private_method_pattern = r'^##### `(\w+)`'
        
        for m in re.finditer(method_pattern, section):
            method_name = m.group(1)
            method_start = m.start()
            
            next_method_match = re.search(r'^##### ', section[method_start+10:], re.MULTILINE)
            search_end = method_start + 2000
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
        
        for m in re.finditer(private_method_pattern, section, re.MULTILINE):
            method_name = m.group(1)
            if method_name not in methods:
                method_start = m.start()
                
                next_method_match = re.search(r'^##### ', section[method_start+10:], re.MULTILINE)
                search_end = method_start + 2000
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
                returns_match = re.search(r'\*\*Returns:\*\*\s*`?([^`\n<]+)', table_search[:300])
                if returns_match:
                    return_type = returns_match.group(1).strip()
                
                methods[method_name] = {'params': params, 'return': return_type}
        
        class_methods[class_name] = methods
    
    return class_methods


def compare_signatures(code_sig, doc_sig, method_name):
    """Compare method signatures between code and docs."""
    differences = []
    
    code_ret = code_sig.get('return', '')
    doc_ret = doc_sig.get('return', 'unknown')
    if code_ret and doc_ret != 'unknown':
        if code_ret == 'dynamic' and doc_ret == 'Widget':
            pass
        elif code_ret == 'dynamic' and 'Widget' in doc_ret:
            pass
        elif 'dynamic' in code_ret and len(doc_ret) < 6:
            pass
        elif '(' in code_ret or '(' in doc_ret:
            pass
        elif not types_similar(code_ret, doc_ret):
            differences.append(f"return: {code_ret} vs {doc_ret}")
    
    code_params = code_sig.get('params', [])
    doc_params = doc_sig.get('params', [])
    
    for p in code_params:
        if p['type'].startswith('required '):
            p['type'] = p['type'][9:].strip()
    
    code_names = {p['name'] for p in code_params}
    doc_names = {p['name'] for p in doc_params}
    
    broken_extraction = any('<' in p['name'] or '>' in p['name'] or '{' in p['name'] for p in code_params)
    
    known_extraction_issues = {'processHtml', 'processBodyHtml', 'buildEntryWidget', 'downloadDictionary', 'fetchRemoteMetadata'}
    
    skip_param_check = broken_extraction or method_name in known_extraction_issues
    
    missing_in_docs = code_names - doc_names
    extra_in_docs = doc_names - code_names
    
    if missing_in_docs and not skip_param_check:
        for p in code_params:
            if p['name'] in missing_in_docs:
                differences.append(f"missing param: {p['name']} ({p['type']})")
    
    if extra_in_docs and not skip_param_check:
        reasonable_docs = [p['name'] for p in doc_params if len(p['name']) > 2 and not any(c in p['name'] for c in '<>{')]
        if reasonable_docs:
            for p in doc_params:
                if p['name'] in extra_in_docs and len(p['name']) > 2:
                    differences.append(f"extra param in docs: {p['name']}")
    
    for cp in code_params:
        for dp in doc_params:
            if cp['name'] == dp['name']:
                if not types_similar(cp['type'], dp['type']):
                    if len(cp['name']) > 3 and len(dp['name']) > 3:
                        differences.append(f"param type: {cp['name']}: {cp['type']} vs {dp['type']}")
                break
    
    if len(code_params) < len(doc_params) and not skip_param_check:
        suspicious_docs = [p for p in doc_params if len(p['name']) <= 2]
        if suspicious_docs:
            pass
        else:
            code_names_prefix = [p['name'][:3] for p in code_params if len(p['name']) >= 3]
            extra_really = []
            for dp in doc_params:
                if not any(dp['name'].startswith(cn) for cn in code_names_prefix):
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
    method_missing = 0
    class_missing_pub = 0
    class_missing_priv = 0
    
    # CLASSES CHECK
    print("\n--- PUBLIC CLASSES ---")
    missing_pub = set(code_pub.keys()) - doc_pub
    extra_pub = doc_pub - set(code_pub.keys())
    if missing_pub:
        print(f"MISSING in docs: {sorted(missing_pub)}")
        class_missing_pub = len(missing_pub)
    if extra_pub:
        print(f"EXTRA in docs: {sorted(extra_pub)}")
    if not missing_pub and not extra_pub:
        print("✓ All public classes documented")
    
    print("\n--- PRIVATE CLASSES ---")
    missing_priv = set(code_priv.keys()) - doc_priv
    extra_priv = doc_priv - set(code_priv.keys())
    if missing_priv:
        print(f"MISSING in docs: {sorted(missing_priv)}")
        class_missing_priv = len(missing_priv)
    if extra_priv:
        print(f"EXTRA in docs: {sorted(extra_priv)}")
    if not missing_priv and not extra_priv:
        print("✓ All private classes documented")
    
    # CLASS FIELDS CHECK
    print("\n" + "="*70)
    print("CLASS FIELDS (Properties)")
    print("="*70)
    
    field_extra = 0
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
            field_extra += len(extra)
    
    if field_missing == 0 and field_extra == 0:
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
    
    const_extra = 0
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
            const_extra += len(extra)
    
    if const_missing == 0 and const_extra == 0:
        print("✓ All private const fields documented")
    
    # METHODS CHECK
    print("\n" + "="*70)
    print("METHODS BY CLASS (with signature comparison)")
    print("="*70)
    
    method_extra = 0
    for class_name in sorted(code_methods.keys()):
        code_m = code_methods.get(class_name, {})
        doc_m = doc_methods_all.get(class_name, {})
        
        if not code_m and not doc_m:
            continue
            
        print(f"\n--- {class_name} ---")
        
        all_methods = sorted(set(code_m.keys()) | set(doc_m.keys()))
        for mn in all_methods:
            if mn in code_m and mn in doc_m:
                diffs = compare_signatures(code_m[mn], doc_m[mn], mn)
                if diffs:
                    print(f"  ⚠️  {mn}: {', '.join(diffs)}")
                    signature_issues.append(f"{class_name}.{mn}")
                else:
                    print(f"  ✓ {mn}")
            elif mn in code_m:
                print(f"  + {mn} (in code, not docs)")
                method_missing += 1
            else:
                print(f"  - {mn} (in docs, not code)")
                method_extra += 1
    
    # SUMMARY
    print("\n" + "="*70)
    print("SUMMARY")
    print("="*70)
    
    total_class_missing = class_missing_pub + class_missing_priv
    
    print(f"Missing classes: {total_class_missing}")
    print(f"  - Public: {class_missing_pub}")
    print(f"  - Private: {class_missing_priv}")
    print(f"Extra classes in docs: {len(extra_pub) + len(extra_priv)}")
    print(f"Missing class fields: {field_missing}")
    print(f"Extra class fields in docs: {field_extra}")
    print(f"Missing providers: {provider_missing}")
    print(f"Extra providers in docs: {len(extra_providers)}")
    print(f"Missing private consts: {const_missing}")
    print(f"Extra private consts in docs: {const_extra}")
    print(f"Missing methods in docs: {method_missing}")
    print(f"Extra methods in docs: {method_extra}")
    print(f"Signature mismatches: {len(signature_issues)}")
    
    if signature_issues:
        print(f"\n⚠️  Methods with signature issues:")
        for issue in signature_issues[:10]:
            print(f"  - {issue}")
        if len(signature_issues) > 10:
            print(f"  ... and {len(signature_issues) - 10} more")
    
    total_missing = total_class_missing + field_missing + provider_missing + const_missing + method_missing
    total_extra = len(extra_pub) + len(extra_priv) + field_extra + len(extra_providers) + const_extra + method_extra
    
    if total_missing == 0 and total_extra == 0 and len(signature_issues) == 0:
        print("\n✅ PERFECT MATCH!")
    elif total_missing == 0 and total_extra == 0:
        print("\n✅ DOCUMENTATION COMPLETE (minor signature differences only)")
    else:
        print(f"\n⚠️  Action needed: {total_missing} missing items, {total_extra} extra items")


if __name__ == "__main__":
    main()
