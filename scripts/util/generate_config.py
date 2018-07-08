from jinja2 import Template
from namesgenerator import get_random_name

data = {
    'nbr_compute_node': 2,
    'nbr_block_node': 1,
    'base_fqdn': 'openstack.dc4.tma.com.vn',
    'passwd_default': "%s" % get_random_name(),
    'passwd_database': "%s" % get_random_name(),
    'passwd_service': "%s" % get_random_name(),
    'passwd_admin': "%s" % get_random_name(),
    'passwd_demo': "%s" % get_random_name(),

}

with open("templates/vars.j2", "r") as f:
    template = Template(f.read())
    # print(template.render(**data))
    with open("out/vars", "w") as ff:
        ff.write(template.render(**data))
