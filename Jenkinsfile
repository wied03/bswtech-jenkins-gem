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

      dockerImage = "quay.io/brady/bswtech-docker-ruby:${readFile('.ruby-version').trim()}"
    }

    stage('Docker Pull') {
      docker.image(dockerImage)
    }

    docker.image(dockerImage).withRun('-u root') {
      stage('Dependencies') {
        sh 'bundle install'
        def builtVersion = ruby.rake('dump_version', true, true)
        currentBuild.description = "${builtVersion} @ <a href=\"https://manage.fury.io/dashboard/wied03/package/EjN5AjN/versions\">Gemfury</a>"
      }

      stage('Test') {
        milestone()
        // RSpec CI reporter
        env.GENERATE_REPORTS = 'true'
        try {
          ruby.rake 'clean spec'
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
          // Need this to verify our signature
          sh "gem cert --add ${env.PUBLIC_KEY_PATH}"
          ruby.rake 'clean build verify_sign'
        }
      }

      if (env.BRANCH_NAME == 'master') {
        stage('Publish GEM') {
          milestone()

          withCredentials([string(credentialsId: 'gemfury_key',
                                  variable: 'gemKey')]) {
            sh "fury push --api-token=${env.gemKey} pkg/*.gem"
          }
          bswKeepBuild()
        }
      }
    }
  }
  catch (any) {
    bswHandleError any
    throw any
  }
}
