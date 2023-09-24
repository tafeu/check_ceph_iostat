example create ceph keyring for nrpe:

ceph auth get-or-create client.nagios mon 'allow r' > /var/lib/nagios/ceph.client.nagios.keyring


example service definition for nagios (notice `use service-grafana`, maybe not what you need)

define service {
        name                            nrpe_ceph_iostat-service
        use                             generic-service5,service-grafana
        service_description             CEPH_IOSTAT
        notification_options            u,c
        check_command                   check_nrpe!check_ceph_iostat
        host_name                       my.hostname.example
}


example service definition for nrpe

command[check_ceph_iostat]=/usr/lib/nagios/plugins/check_ceph_iostat.pl --id nagios --keyring /var/lib/nagios/ceph.client.nagios.keyring

histou template

<?php /* CEPH_IOSTAT Template */

$rule = new \histou\template\Rule(
    $host = '*',
    $service = 'CEPH_IOSTAT',
    $command = '*',
    $perfLabel = array('rd', 'wr', 'read iops', 'write iops')
);

$genTemplate = function ($perfData) {
    $colors = array('#EA8F00', '#AACC01', '#07ff78', '#4707ff', '#f71717');
    $dashboard = \histou\grafana\dashboard\DashboardFactory::generateDashboard($perfData['host'].'-'.$perfData['service']);
foreach (array('throughput', 'iops') as $memtype) {
    $row = new \histou\grafana\Row($perfData['host'].' '.$perfData['service'].' '.$perfData['command']);
    $panel = \histou\grafana\graphpanel\GraphPanelFactory::generatePanel($perfData['host'].' '.$perfData['service'].' '.$memtype);
    foreach ($perfData['perfLabel'] as $key => $values) {

        if (
          ( $memtype === 'throughput' && ( $key === 'read iops' || $key === 'write iops' ) )
        ||
          ($memtype === 'iops' && ( $key === 'rd' || $key === 'wr') )
        ) { continue; }

        if ($key === 'rd' || $key === 'read iops'){
           $color = $colors[2];
        } else {
           $color = $colors[0];
        }

        $target = $panel->genTargetSimple($perfData['host'], $perfData['service'], $perfData['command'], $key, $color);
        $panel->addTarget($target);
        $downtime = $panel->genDowntimeTarget($perfData['host'], $perfData['service'], $perfData['command'], $key);
        $panel->addTarget($downtime);
        if (isset($values['unit'])) { $panel->setLeftUnit($values['unit']); }

    }
    $row->addPanel($panel);
    $dashboard->addRow($row);
}
    $dashboard->addDefaultAnnotations($perfData['host'], $perfData['service']);
    return $dashboard;
};
