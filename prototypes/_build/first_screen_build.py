# Builds the four first-screen demos from one template. Run: python first_screen_build.py
import os

here = os.path.dirname(os.path.abspath(__file__))
tpl = open(os.path.join(here, 'first_screen_template.html'), encoding='utf-8').read()
out = os.path.join(here, '..')
for role in ('customer', 'client', 'driver', 'admin'):
    html = tpl.replace('/*ROLE_LINE*/', "window.ROLE = '%s';" % role)
    path = os.path.normpath(os.path.join(out, '%s_overall_demo.html' % role))
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(html)
    print(path)
