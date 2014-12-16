# -*- coding: utf-8 -*-
'''
Management of Neutron resources
===============================

:depends:   - neutronclient Python module
:configuration: See :py:mod:`salt.modules.neutron` for setup instructions.

.. code-block:: yaml

    neutron network present:
      neutron.network_present:
        - name: Netone
        - provider_physical_network: PHysnet1
        - provider_network_type: vlan
'''
import logging
from functools import wraps
LOG = logging.getLogger(__name__)


def __virtual__():
    '''
    Only load if glance module is present in __salt__
    '''
    return 'neutron' if 'neutron.list_networks' in __salt__ else False


def _test_call(method):
    (resource, functionality) = method.func_name.split('_')
    if functionality == 'present':
        functionality = 'updated'
    else:
        functionality = 'removed'

    @wraps(method)
    def check_for_testing(name, *args, **kwargs):
        if __opts__.get('test', None):
            return _no_change(name, resource, test=functionality)
        return method(name, *args, **kwargs)
    return check_for_testing


def _neutron_module_call(method, *args, **kwargs):
    return __salt__['neutron.{0}'.format(method)](*args, **kwargs)


@_test_call
def network_present(name=None,
                    provider_network_type=None,
                    provider_physical_network=None,
                    router_external=None,
                    admin_state_up=None,
                    shared=None,
                    **connection_args):
    '''
    Ensure that the neutron network is present with the specified properties.

    name
        The name of the network to manage
    '''
    existing_network = _neutron_module_call(
        'list_networks', name=name, **connection_args)
    network_arguments = _get_non_null_args(
        name=name,
        provider_network_type=provider_network_type,
        provider_physical_network=provider_physical_network,
        router_external=router_external,
        admin_state_up=admin_state_up,
        shared=shared)
    if not existing_network:
        network_arguments.update(connection_args)
        _neutron_module_call('create_network', **network_arguments)
        existing_network = _neutron_module_call(
            'list_networks', name=name, **connection_args)
        if existing_network:
            return _created(name, 'network', existing_network[name])
        return _update_failed(name, 'network')
    # map internal representation to display format
    LOG.error('existing ' + str(existing_network))
    LOG.error('new ' + str(network_arguments))
    existing_network = dict((key.replace(':', '_', 1), value)
                            for key, value in
                            existing_network[name].iteritems())
    # generate differential
    diff = dict((key, value) for key, value in network_arguments.iteritems()
                if existing_network.get(key, None) != value)
    if diff:
        # update the changes
        network_arguments = diff.copy()
        network_arguments.update(connection_args)
        try:
            LOG.debug('updating network {0} with changes {1}'.format(
                name, str(diff)))
            _neutron_module_call('update_network',
                                 existing_network['id'],
                                 **network_arguments)
            changes_dict = _created(name, 'network', diff)
            changes_dict['comment'] = '{1} {0} updated'.format(name, 'network')
            return changes_dict
        except:
            LOG.exception('Could not update network {0}'.format(name))
            return _update_failed(name, 'network')
    return _no_change(name, 'network')


@_test_call
def network_absent(name, **connection_args):
    existing_network = _neutron_module_call(
        'list_networks', name=name, **connection_args)
    if existing_network:
        _neutron_module_call(
            'delete_network', existing_network[name]['id'], **connection_args)
        if _neutron_module_call('list_networks', name=name, **connection_args):
            return _delete_failed(name, 'network')
        return _deleted(name, 'network', existing_network[name])
    return _absent(name, 'network')


@_test_call
def subnet_present(name=None,
                   network=None,
                   cidr=None,
                   ip_version=4,
                   enable_dhcp=True,
                   allocation_pools=None,
                   gateway_ip=None,
                   dns_nameservers=None,
                   host_routes=None,
                   **connection_args):
    '''
    Ensure that the neutron subnet is present with the specified properties.

    name
        The name of the subnet to manage
    '''
    existing_subnet = _neutron_module_call(
        'list_subnets', name=name, **connection_args)
    subnet_arguments = _get_non_null_args(
        name=name,
        network=network,
        cidr=cidr,
        ip_version=ip_version,
        enable_dhcp=enable_dhcp,
        allocation_pools=allocation_pools,
        gateway_ip=gateway_ip,
        dns_nameservers=dns_nameservers,
        host_routes=host_routes)
    # replace network with network_id
    if 'network' in subnet_arguments:
        network = subnet_arguments.pop('network', None)
        existing_network = _neutron_module_call(
            'list_networks', name=network, **connection_args)
        if existing_network:
            subnet_arguments['network_id'] = existing_network[network]['id']
    if not existing_subnet:
        subnet_arguments.update(connection_args)
        _neutron_module_call('create_subnet', **subnet_arguments)
        existing_subnet = _neutron_module_call(
            'list_subnets', name=name, **connection_args)
        if existing_subnet:
            return _created(name, 'subnet', existing_subnet[name])
        return _update_failed(name, 'subnet')
    # change from internal representation
    existing_subnet = existing_subnet[name]
    # create differential
    LOG.error('existing ' + str(existing_subnet))
    LOG.error('new ' + str(subnet_arguments))
    diff = dict((key, value) for key, value in subnet_arguments.iteritems()
                if existing_subnet.get(key, None) != value)
    if diff:
        # update the changes
        subnet_arguments = diff.copy()
        subnet_arguments.update(connection_args)
        try:
            LOG.debug('updating subnet {0} with changes {1}'.format(
                name, str(diff)))
            _neutron_module_call('update_subnet',
                                 existing_subnet['id'],
                                 **subnet_arguments)
            changes_dict = _created(name, 'subnet', diff)
            changes_dict['comment'] = '{1} {0} updated'.format(name, 'subnet')
            return changes_dict
        except:
            LOG.exception('Could not update subnet {0}'.format(name))
            return _update_failed(name, 'subnet')
    return _no_change(name, 'subnet')


@_test_call
def subnet_absent(name, **connection_args):
    existing_subnet = _neutron_module_call(
        'list_subnets', name=name, **connection_args)
    if existing_subnet:
        _neutron_module_call(
            'delete_subnet', existing_subnet[name]['id'], **connection_args)
        if _neutron_module_call('list_subnets', name=name, **connection_args):
            return _delete_failed(name, 'subnet')
        return _deleted(name, 'subnet', existing_subnet[name])
    return _absent(name, 'subnet')
    return _absent(name, 'network')


@_test_call
def router_present(name=None,
                   gateway_network=None,
                   interfaces=None,
                   admin_state_up=None,
                   **connection_args):
    '''
    Ensure that the neutron router is present with the specified properties.

    name
        The name of the subnet to manage
    gateway_network
        The network that would be the router's default gateway
    interfaces
        list of subnets the router attaches to
    '''

    existing_router = _neutron_module_call(
        'list_routers', name=name, **connection_args)
    if not existing_router:
        _neutron_module_call('create_router', name=name, **connection_args)
        created_router = _neutron_module_call(
            'list_routers', name=name, **connection_args)
        if created_router:
            router_id = created_router[name]['id']
            network = _neutron_module_call(
                'list_networks', name=gateway_network, **connection_args)
            gateway_network_id = network[gateway_network]['id']
            _neutron_module_call('router_gateway_set',
                                 router_id=router_id,
                                 external_gateway=gateway_network_id,
                                 **connection_args)
            for interface in interfaces:
                subnet = _neutron_module_call(
                    'list_subnets', name=interface, **connection_args)
                subnet_id = subnet[interface]['id']
                _neutron_module_call('router_add_interface',
                                     router_id=router_id,
                                     subnet_id=subnet_id,
                                     **connection_args)
            return _created(name,
                            'router',
                            _neutron_module_call('list_routers',
                                                 name=name,
                                                 **connection_args))
        return _create_failed(name, 'router')
    existing_router = existing_router[name]
    diff = {}
    if admin_state_up and existing_router['admin_state_up'] != admin_state_up:
        diff.update({'admin_state_up': admin_state_up})
    if gateway_network:
        network = _neutron_module_call(
            'list_networks', name=gateway_network, **connection_args)
        gateway_network_id = network[gateway_network]['id']
        if not existing_router['external_gateway_info'] :
            if existing_router['external_gateway_info']['network_id'] != gateway_network_id:
                diff.update({'external_gateway_info': {'network_id': gateway_network_id}})
        else:
            diff.update({'external_gateway_info': {'network_id': gateway_network_id}})
    if diff:
        # update the changes
        router_args = diff.copy()
        router_args.update(connection_args)
        try:
            _neutron_module_call('update_router', existing_router['id'], **router_args)
            changes_dict = _created(name, 'router', diff)
            changes_dict['comment'] = 'Router {0} updated'.format(name)
            return changes_dict
        except:
            LOG.exception('Router {0} could not be updated'.format(name))
            return _update_failed(name, 'router')
    return _no_change(name, 'router')


def security_group_present(name=None,
                           description=None,
                           rules=[],
                           **connection_args):
    '''
    Ensure that the security group is present with the specified properties.

    name
        The name of the security group
    description
        The description of the security group
    rules
        list of rules the security group has
    '''

    existing_sec_group = _neutron_module_call(
        'list_security_groups', name=name, **connection_args)
    if not existing_sec_group:
        security_group_id = _neutron_module_call(
                                    'create_security_group',
                                    name=name,
                                    description=description,
                                    **connection_args)
    else:
        security_group_id = existing_sec_group[name]['id']

    for rule in rules:
        start_port = rule['from-port'] if rule['from-port'] != 'None' else None
        end_port = rule['to-port'] if rule['to-port'] != 'None' else None
        _neutron_module_call(
            'create_security_group_rule',
            security_group_id=security_group_id,
            direction=rule['direction'],
            protocol=rule['protocol'],
            ethertype='ipv4',
            port_range_min=start_port,
            port_range_max=end_port,
            remote_ip_prefix=rule['cidr'],
            **connection_args)

    created_security_group = _neutron_module_call(
        'list_security_groups', name=name, **connection_args)
    return _created(name, 'security_group', created_security_group[name])


def _created(name, resource, resource_definition):
    changes_dict = {'name': name,
                    'changes': resource_definition,
                    'result': True,
                    'comment': '{0} {1} created'.format(resource, name)}
    return changes_dict


def _no_change(name, resource, test=False):
    changes_dict = {'name': name,
                    'changes': {},
                    'result': True}
    if test:
        changes_dict['comment'] = \
            '{0} {1} will be {2}'.format(resource, name, test)
    else:
        changes_dict['comment'] = \
            '{0} {1} is in correct state'.format(resource, name)
    return changes_dict


def _deleted(name, resource, resource_definition):
    changes_dict = {'name': name,
                    'changes': {},
                    'comment': '{0} {1} removed'.format(resource, name),
                    'result': True}
    return changes_dict


def _absent(name, resource):
    changes_dict = {'name': name,
                    'changes': {},
                    'comment': '{0} {1} not present'.format(resource, name),
                    'result': True}
    return changes_dict


def _delete_failed(name, resource):
    changes_dict = {'name': name,
                    'changes': {},
                    'comment': '{0} {1} failed to delete'.format(resource,
                                                                 name),
                    'result': False}
    return changes_dict

def _create_failed(name, resource):
    changes_dict = {'name': name,
                    'changes': {},
                    'comment': '{0} {1} failed to create'.format(resource,
                                                                 name),
                    'result': False}
    return changes_dict

def _update_failed(name, resource):
    changes_dict = {'name': name,
                    'changes': {},
                    'comment': '{0} {1} failed to update'.format(resource,
                                                                 name),
                    'result': False}
    return changes_dict


def _get_non_null_args(**kwargs):
    '''
    Return those kwargs which are not null
    '''
    return dict((key, value,) for key, value in kwargs.iteritems()
                if value is not None)
