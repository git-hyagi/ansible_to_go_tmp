* copy simple.yaml to /tmp
* on the pulp-operator src repo
  * git checkout ansible
  * run ansible.sh
* wait until playbook stop execution (converges)
* on the pulp-operator src repo
  * git checkout backup-ansible-compatibility
  * run go.sh
