import uuid

from jinja2 import Template
from namesgenerator import get_random_name

def get_random_str(block=1):
    s = uuid.uuid4()
    return str(s).split('-')[block]

data = {
    'nbr_compute_node': 2,
    'nbr_block_node': 1,
    'base_fqdn': 'openstack.dc4.tma.com.vn',
    'passwd_default': "%s_%s" % (get_random_name(), get_random_str(4)),
    'passwd_database': "%s_%s" % (get_random_name(), get_random_str(0)),
    'passwd_service': "%s_%s" % (get_random_name(), get_random_str(4)),
    'passwd_admin': "%s_%s_%s" % (get_random_str(1), get_random_name(), get_random_str(1)),
    'passwd_demo': "%s" % get_random_name(),

}

with open("templates/vars.j2", "r") as f:
    template = Template(f.read())
    # print(template.render(**data))
    with open("out/vars", "w") as ff:
        ff.write(template.render(**data))
