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

      dockerImage = "ruby:${readFile('.ruby-version').trim()}"
    }

    stage('Docker Pull') {
      docker.image(dockerImage)
    }

    docker.image(dockerImage).inside {
      stage('Dependencies') {
        sh 'bundle install'
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

      stage('Build GEM') {
        milestone()
        withCredentials([
                          file(credentialsId: 'gem_public_key', variable: 'PUBLIC_KEY_PATH'),
                          file(credentialsId: 'gem_private_key', variable: 'PRIVATE_KEY_PATH')
                        ]) {
          ruby.rake 'build'
        }
        archiveArtifacts artifacts: 'pkg/*.gem',
                         excludes: null
      }

      if (env.BRANCH_NAME == 'master') {
        stage('Publish GEM') {
          milestone()

          node('docker.build') {
            withCredentials([string(credentialsId: credential_id,
                                    variable: 'gemKey')]) {
              sh "fury push --api-token=${env.gemKey} pkg/*.gem"
            }
          }
        }
      }
    }
  }
  catch (any) {
    bswHandleError any
    throw any
  }
}
