#!/usr/bin/env python3
"""Regenerates sciperiodictable_elements.lrs from sciperiodictable_elements.csv.
Run it from the package folder whenever the CSV changes."""
import sys

SRC = 'sciperiodictable_elements.csv'
DST = 'sciperiodictable_elements.lrs'
NAME = 'SCIPERIODICTABLE_ELEMENTS'
TYPE = 'RCDATA'
MAXLINE = 72

def pascal_lines(data):
    """Encodes bytes as Pascal literal lines: 'text' runs and #nn codes."""
    lines, cur, in_quote = [], '', False
    def close():
        nonlocal cur, in_quote
        if in_quote:
            cur += "'"
            in_quote = False
    for b in data:
        if 32 <= b < 127:
            tok = "''" if b == 0x27 else chr(b)
            if not in_quote:
                tok = "'" + tok
            if len(cur) + len(tok) + 1 > MAXLINE:
                close(); lines.append(cur); cur = ''
                tok = "'" + ("''" if b == 0x27 else chr(b))
            cur += tok
            in_quote = True
        else:
            close()
            tok = '#%d' % b
            if len(cur) + len(tok) > MAXLINE:
                lines.append(cur); cur = ''
            cur += tok
    close()
    if cur:
        lines.append(cur)
    return lines

data = open(SRC, 'rb').read()
lines = pascal_lines(data)
with open(DST, 'w', newline='\n') as f:
    f.write("LazarusResources.Add('%s','%s',[\n" % (NAME, TYPE))
    f.write(',\n'.join('  ' + l for l in lines))
    f.write('\n]);\n')
print('%s: %d bytes -> %s' % (SRC, len(data), DST))
