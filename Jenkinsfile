// CI for the Puppet control repo.
// Tooling is installed on the Jenkins VM by labs/puppet/04_configure_jenkins_for_puppet.yml
pipeline {
    agent any

    triggers {
        // Poll GitHub every 5 minutes (webhooks require a public URL)
        pollSCM('H/5 * * * *')
    }

    environment {
        PUPPET      = '/opt/puppetlabs/bin/puppet'
        PUPPET_LINT = '/opt/puppetlabs/puppet/bin/puppet-lint'
        R10K        = '/opt/puppetlabs/puppet/bin/r10k'
        RUBY        = '/opt/puppetlabs/puppet/bin/ruby'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Tool Versions') {
            steps {
                sh '''
                    echo "puppet:      $($PUPPET --version)"
                    echo "puppet-lint: $($PUPPET_LINT --version)"
                    echo "r10k:        $($R10K version)"
                '''
            }
        }

        stage('Puppetfile Syntax') {
            steps {
                sh '$R10K puppetfile check'
            }
        }

        stage('YAML Syntax (Hiera)') {
            steps {
                sh '''
                    FAILED=0
                    for f in hiera.yaml $(find data -name '*.yaml'); do
                        echo "  Checking: $f"
                        $RUBY -ryaml -e "YAML.load_file(ARGV[0])" "$f" || { echo "  FAIL: $f"; FAILED=1; }
                    done
                    exit $FAILED
                '''
            }
        }

        stage('Puppet Parser Validate') {
            steps {
                sh '''
                    find manifests site-modules -name '*.pp' -print0 \
                        | xargs -0 $PUPPET parser validate
                    for t in $(find site-modules -name '*.epp'); do
                        echo "  Checking: $t"
                        $PUPPET epp validate "$t"
                    done
                '''
            }
        }

        stage('Puppet Lint') {
            steps {
                sh '''
                    $PUPPET_LINT --fail-on-warnings \
                        --no-140chars-check \
                        manifests site-modules
                '''
            }
        }

    }

    post {
        success {
            echo "Control repo passed all checks."
        }
        failure {
            echo "Pipeline failed — fix the issues above before r10k deploys them."
        }
        always {
            cleanWs()
        }
    }
}
