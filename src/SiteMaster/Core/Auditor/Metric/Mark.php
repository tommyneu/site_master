<?php
namespace SiteMaster\Core\Auditor\Metric;

use DB\Record;
use SiteMaster\Core\Registry\Site\Member;

class Mark extends Record
{
    public $id;                    //int required
    public $metrics_id;             //fk for metrics.id NOT NULL
    public $machine_name;          //VARCHAR(64) NOT NULL, machine readable name
    public $name;                  //TEXT NOT NULL, human readable name
    public $point_deduction;       //DECIMAL(2,2) NOT NULL default=0, points to take off for the mark
    public $description;           //TEXT, a description of the error
    public $help_text;             //TEXT, a how-to-fix text (will be editable by admin)

    public function keys()
    {
        return array('id');
    }

    public static function getTable()
    {
        return 'marks';
    }

    /**
     * Get a mark by a machine name and metric id
     * 
     * @param $machine_name
     * @param $metric_id
     * @return bool|Mark
     */
    public static function getByMachineNameAndMetricID($machine_name, $metric_id)
    {
        return self::getByAnyField(__CLASS__, 'machine_name', $machine_name, 'metrics_id=' . (int)$metric_id);
    }

    /**
     * Create a new Scan
     *
     * @param $metric_id
     * @param $machine_name
     * @param $name
     * @param array $fields
     * @return bool|Mark
     */
    public static function createNewMark($metric_id, $machine_name, $name, array $fields = array())
    {
        $scan = new self();
        $scan->point_deduction = 0;
        $scan->synchronizeWithArray($fields);
        $scan->metrics_id    = $metric_id;
        $scan->machine_name = $machine_name;
        $scan->name         = $name;

        if (!$scan->insert()) {
            return false;
        }
        
        return $scan;
    }
}
