// should only need 3 master builds (code will mark published builds as permanent)
if (env.BRANCH_NAME == 'master') {
  properties([[$class: 'BuildDiscarderProperty',
               strategy: [$class: 'LogRotator',
                          artifactDaysToKeepStr: '',
                          artifactNumToKeepStr: '',
                          daysToKeepStr: '',
                          numToKeepStr: '3']
              ]])
}
else {
  // build numbers are not unique across branches
  env.BUILD_NUMBER = "${env.BRANCH_NAME}.${env.BUILD_NUMBER}"
}

node('docker.build') {
  try {
    stage('Checkout') {
      checkout([
        $class: 'GitSCM',
        branches: scm.branches,
        extensions: scm.extensions + [[$class: 'CleanCheckout']],
        userRemoteConfigs: scm.userRemoteConfigs
      ])
      rubyVersion = readFile('.ruby-version').trim()
    }

    docker.image("ruby:${rubyVersion}").inside {
      stage('Dependencies') {
        shell('bundle install')
      }

      stage('Test') {
        milestone()
        // RSpec CI reporter
        env.GENERATE_REPORTS = 'true'
        try {
          ruby.rake 'spec'
        }
        finally {
          junit keepLongStdio: true,
                testResults: 'spec/reports/*.xml'
        }
      }
    }
  }
  catch (any) {
    bswHandleError any
    throw any
  }
}

// only allow pushing from master
if (env.BRANCH_NAME == 'notyet') {
  stage('Publish Image') {
    milestone()

    node('docker.build') {
      try {
        // might be on a different node (filesystem deps)
        unstash 'complete-workspace'
        ruby.with_gem_credentials(furyRepo, furyCredentialId) {
          ruby.dependencies()
        }

        // 2nd arg is creds
        docker.withRegistry('https://quay.io', 'quay_io_docker') {
          ruby.rake 'push'
        }
        bswKeepBuild()
        archiveArtifacts artifacts: 'plugins/Gemfile.lock',
                         excludes: null
      }
      catch (any) {
        bswHandleError any
        throw any
      }
    }
  }
}