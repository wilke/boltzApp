package Bio::KBase::AppService::AppConfig;

# Minimal AppConfig for standalone container deployment
# Generated for BV-BRC Boltz container
# Values can be overridden via environment variables

use constant data_api_url => $ENV{BVBRC_DATA_API_URL} // 'https://www.bv-brc.org/api';
use constant binning_data_api_url => $ENV{BVBRC_BINNING_DATA_API_URL} // 'https://www.bv-brc.org/api';
use constant db_host => $ENV{BVBRC_DB_HOST} // '';
use constant db_user => $ENV{BVBRC_DB_USER} // '';
use constant db_pass => $ENV{BVBRC_DB_PASS} // '';
use constant db_name => $ENV{BVBRC_DB_NAME} // '';
use constant seedtk => $ENV{BVBRC_SEEDTK} // '/vol/seedtk';
use constant github_issue_repo_owner => $ENV{BVBRC_GITHUB_ISSUE_REPO_OWNER} // '';
use constant github_issue_repo_name => $ENV{BVBRC_GITHUB_ISSUE_REPO_NAME} // '';
use constant github_issue_token => $ENV{BVBRC_GITHUB_ISSUE_TOKEN} // '';
use constant reference_data_dir => $ENV{BVBRC_REFERENCE_DATA_DIR} // '/vol/bvbrc/reference-data';
use constant binning_genome_annotation_clientgroup => $ENV{BVBRC_BINNING_CLIENTGROUP} // '';
use constant mash_reference_sketch => $ENV{BVBRC_MASH_SKETCH} // '';
use constant binning_spades_threads => $ENV{BVBRC_SPADES_THREADS} // 8;
use constant binning_spades_ram => $ENV{BVBRC_SPADES_RAM} // 64;
use constant kma_db => $ENV{BVBRC_KMA_DB} // '';
use constant metagenome_dbs => $ENV{BVBRC_METAGENOME_DBS} // '';
use constant application_backend_dir => $ENV{BVBRC_APP_BACKEND_DIR} // '/kb/deployment';
use constant sched_db_host => $ENV{BVBRC_SCHED_DB_HOST} // '';
use constant sched_db_port => $ENV{BVBRC_SCHED_DB_PORT} // 3306;
use constant sched_db_user => $ENV{BVBRC_SCHED_DB_USER} // '';
use constant sched_db_pass => $ENV{BVBRC_SCHED_DB_PASS} // '';
use constant sched_db_name => $ENV{BVBRC_SCHED_DB_NAME} // '';
use constant sched_default_cluster => $ENV{BVBRC_SCHED_DEFAULT_CLUSTER} // '';
use constant redis_host => $ENV{BVBRC_REDIS_HOST} // '';
use constant redis_port => $ENV{BVBRC_REDIS_PORT} // 6379;
use constant redis_db => $ENV{BVBRC_REDIS_DB} // 0;
use constant redis_password => $ENV{BVBRC_REDIS_PASSWORD} // '';
use constant slurm_control_task_partition => $ENV{BVBRC_SLURM_PARTITION} // '';
use constant bebop_binning_user => $ENV{BVBRC_BEBOP_USER} // '';
use constant bebop_binning_key => $ENV{BVBRC_BEBOP_KEY} // '';
use constant app_directory => $ENV{BVBRC_APP_DIRECTORY} // '/kb/module/app_specs';
use constant app_service_url => $ENV{BVBRC_APP_SERVICE_URL} // 'https://p3.theseed.org/services/app_service';

use base 'Exporter';
our @EXPORT_OK = qw(data_api_url github_issue_repo_owner github_issue_repo_name github_issue_token
                    db_host db_user db_pass db_name
                    seedtk reference_data_dir
                    bebop_binning_user bebop_binning_key
                    sched_db_host sched_db_port sched_db_user sched_db_pass sched_db_name
                    sched_default_cluster
                    slurm_control_task_partition
                    binning_spades_threads binning_spades_ram
                    binning_genome_annotation_clientgroup mash_reference_sketch
                    app_directory app_service_url
                    redis_host redis_port redis_db redis_password
                    kma_db metagenome_dbs application_backend_dir
                    binning_data_api_url
                    );
our %EXPORT_TAGS = (all => [@EXPORT_OK]);
1;
