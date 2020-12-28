import setuptools

setuptools.setup(
    name = 'sonic-frr-mgmt-framework',
    version = '1.0',
    description = 'Utility to dynamically configuration FRR based on database update',
    url = 'https://github.com/Azure/sonic-buildimage',
    packages = setuptools.find_packages(),
    entry_points = {
        'console_scripts': [
            'frrcfgd = frrcfgd.frrcfgd:main',
        ]
    },
    install_requires = [
        'jinja2>=2.10',
        'netaddr==0.8.0',
        'pyyaml==5.3.1',
        'zipp==1.2.0', # importlib-resources needs zipp and seems to have a bug where it will try to import too new of a version for Python 2
    ],
    setup_requires = [
        'pytest-runner',
        'wheel'
    ],
    tests_require = [
        'pytest',
        'pytest-cov',
        'sonic-config-engine'
    ]
)
