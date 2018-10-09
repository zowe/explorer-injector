#!groovy

/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018
 */


def isPullRequest = env.BRANCH_NAME.startsWith('PR-')

def opts = []
// keep last 20 builds for regular branches, no keep for pull requests
opts.push(buildDiscarder(logRotator(numToKeepStr: (isPullRequest ? '' : '20'))))
// disable concurrent build
opts.push(disableConcurrentBuilds())
// set upstream triggers
if (env.BRANCH_NAME == 'master') {
  opts.push(pipelineTriggers([
    upstream(threshold: 'SUCCESS', upstreamProjects: '/atlas-server,/explorer-jes-pipeline/master,/explorer-mvs-pipeline/master,/explorer-uss-pipeline/master')
  ]))
}

// define custom build parameters
def customParameters = []
customParameters.push(string(
  name: 'ARTIFACTORY_SERVER',
  description: 'Artifactory server, should be pre-defined in Jenkins configuration',
  defaultValue: 'gizaArtifactory',
  trim: true
))
customParameters.push(string(
  name: 'TEST_SERVER_IP',
  description: 'The server IP used to run test cases',
  defaultValue: '172.30.0.1',
  trim: true
))
customParameters.push(credentials(
  name: 'TEST_SERVER_CREDENTIALS_ID',
  description: 'The server credential used to run test cases',
  credentialType: 'com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl',
  defaultValue: 'TestAdminzOSaaS2',
  required: true
))
customParameters.push(string(
  name: 'ATLAS_APPS_DIR',
  description: 'The apps folder where Atlas service installed.',
  defaultValue: '/zaas1/atlas/wlp/usr/servers/Atlas/apps',
  trim: true
))
customParameters.push(string(
  name: 'ATLAS_ROOT_DIR',
  description: 'The Atlas root folder where Atlas service installed.',
  defaultValue: '/zaas1/atlas',
  trim: true
))
customParameters.push(string(
  name: 'ATLAS_SERVICE_NAME',
  description: 'The Atlas service name will be restarted.',
  defaultValue: 'FEKATLS',
  trim: true
))
customParameters.push(booleanParam(
  name: 'RESTART_ATLAS',
  description: 'If need to restart Atlas service after replacement.',
  defaultValue: true
))
opts.push(parameters(customParameters))

// set build properties
properties(opts)

node ('jenkins-slave') {
  currentBuild.result = 'SUCCESS'

  try {

    stage('checkout'){
      // checkout source code
      checkout scm

      // check if it's pull request
      echo "Current branch is ${env.BRANCH_NAME}"
      if (isPullRequest) {
        echo "This is a pull request"
      }
    }

    stage('prepare') {
      echo 'downloading war files ...'

      // download-atlas-war
      def server = Artifactory.server params.ARTIFACTORY_SERVER
      def downloadSpec = readFile "artifactory-download-spec.json"
      server.download(downloadSpec)
    }

    stage('inject') {
      echo 'uploading to test server ...'

      withCredentials([usernamePassword(credentialsId: params.TEST_SERVER_CREDENTIALS_ID, passwordVariable: 'PASSWORD', usernameVariable: 'USERNAME')]) {
        // send file to test image host
        sh """SSHPASS=${PASSWORD} sshpass -e sftp -o BatchMode=no -o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no -b - ${USERNAME}@${params.TEST_SERVER_IP} << EOF
cd ${params.ATLAS_APPS_DIR}
put .tmp/atlas-server.war
put .tmp/explorer-mvs.war
put .tmp/explorer-uss.war
put .tmp/explorer-jes.war
ls -al
EOF"""

        if (params.RESTART_ATLAS) {
          sh """SSHPASS=${PASSWORD} sshpass -e ssh -tt -o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no ${USERNAME}@${params.TEST_SERVER_IP} << EOF
cd ${params.ATLAS_APPS_DIR} && \
  cd /u/tstradm && \
  pwd && ls -al && \
  (opercmd "C ${params.ATLAS_SERVICE_NAME}" || true) && sleep 10 && \
  (opercmd "S ${params.ATLAS_SERVICE_NAME},SRVRPATH='${params.ATLAS_ROOT_DIR}'") || { echo "[restart-atlas] failed"; exit 1; }
echo "[restart-atlas] succeeds" && exit 0
EOF"""
        }
      }
    }

    stage('done') {
      // send out notification
      emailext body: "Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} success.\n\nCheck detail: ${env.BUILD_URL}" ,
          subject: "[Jenkins] Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} success",
          recipientProviders: [
            [$class: 'RequesterRecipientProvider'],
            [$class: 'CulpritsRecipientProvider'],
            [$class: 'DevelopersRecipientProvider'],
            [$class: 'UpstreamComitterRecipientProvider']
          ]
    }

  } catch (err) {
    currentBuild.result = 'FAILURE'

    // catch all failures to send out notification
    emailext body: "Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} failed.\n\nError: ${err}\n\nCheck detail: ${env.BUILD_URL}" ,
        subject: "[Jenkins] Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} failed",
        recipientProviders: [
          [$class: 'RequesterRecipientProvider'],
          [$class: 'CulpritsRecipientProvider'],
          [$class: 'DevelopersRecipientProvider'],
          [$class: 'UpstreamComitterRecipientProvider']
        ]

    throw err
  }
}
