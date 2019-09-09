//
// Copyright (c) 2019, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//

import ballerina/encoding;
import ballerina/filepath;
import ballerina/io;
import ballerina/log;

# CSV insert operator client.
public type CsvInsertOperator client object {
    JobInfo job;
    SalesforceBaseClient httpBaseClient;

    public function __init(JobInfo job, SalesforceConfiguration salesforceConfig) {
        self.job = job;
        self.httpBaseClient = new(salesforceConfig);
    }

    # Create CSV insert batch.
    #
    # + csvContent - insertion data in CSV format
    # + return - BatchInfo record if successful else ConnectorError occured
    public remote function insert(string csvContent) returns @tainted BatchInfo|ConnectorError {
        xml|ConnectorError xmlResponse = self.httpBaseClient->createCsvRecord([JOB, self.job.id, BATCH], csvContent);
        if (xmlResponse is xml) {
            BatchInfo|ConnectorError batch = getBatch(xmlResponse);
            return batch;
        } else {
            return xmlResponse;
        }
    }

    # Create CSV insert batch using a CSV file.
    #
    # + filePath - insertion CSV file path
    # + return - BatchInfo record if successful else ConnectorError occured
    public remote function insertFile(string filePath) returns @tainted BatchInfo|ConnectorError {
        if (filepath:extension(filePath) == "csv") {
            io:ReadableByteChannel|io:Error rbc = io:openReadableFile(filePath);

            if (rbc is io:Error) {
                string errMsg = "Error occurred while reading the csv file, file: " + filePath;
                log:printError(errMsg, err = rbc);
                IOError ioError = error(IO_ERROR, message = errMsg, errorCode = IO_ERROR, cause = rbc);
                return ioError;
            } else {
                // Read content.
                byte[] readContent;
                string textContent = "";
                while (true) {
                    byte[]|io:Error result = rbc.read(1000);
                    if (result is io:EofError) {
                        break;
                    } else if (result is io:Error) {
                        string errMsg = "Error occurred while reading the csv file, file: " + filePath;
                        log:printError(errMsg, err = result);
                        IOError ioError = error(IO_ERROR, message = errMsg, errorCode = IO_ERROR, cause = result);
                        return ioError;
                    } else {
                        readContent = result;  
                        textContent = textContent + encoding:encodeBase64Url(readContent);                      
                    }
                }
                // close channel.
                closeRb(rbc);

                xml|ConnectorError response =
                self.httpBaseClient->createCsvRecord([<@untainted> JOB, self.job.id, <@untainted> BATCH], textContent);

                if (response is xml) {
                    BatchInfo|ConnectorError batch = getBatch(response);
                    return batch;
                } else {
                    return response;
                }
            }
        } else {
            string errMsg = "Invalid file type, file: " + filePath;
            log:printError(errMsg, err = ());
            IOError ioError = error(IO_ERROR, message = errMsg, errorCode = IO_ERROR);
            return ioError;
        }
    }

    # Get CSV insert operator job information.
    #
    # + return - JobInfo record if successful else ConnectorError occured
    public remote function getJobInfo() returns @tainted JobInfo|ConnectorError {
        xml|ConnectorError xmlResponse = self.httpBaseClient->getXmlRecord([JOB, self.job.id]);
        if (xmlResponse is xml) {
            JobInfo|ConnectorError job = getJob(xmlResponse);
            return job;
        } else {
            return xmlResponse;
        }
    }

    # Close CSV insert operator job.
    #
    # + return - JobInfo record if successful else ConnectorError occured
    public remote function closeJob() returns @tainted JobInfo|ConnectorError {
        xml|ConnectorError xmlResponse = self.httpBaseClient->createXmlRecord([JOB, self.job.id],
        XML_STATE_CLOSED_PAYLOAD);
        if (xmlResponse is xml) {
            JobInfo|ConnectorError job = getJob(xmlResponse);
            return job;
        } else {
            return xmlResponse;
        }
    }

    # Abort CSV insert operator job.
    #
    # + return - JobInfo record if successful else ConnectorError occured
    public remote function abortJob() returns @tainted JobInfo|ConnectorError {
        xml|ConnectorError xmlResponse = self.httpBaseClient->createXmlRecord([JOB, self.job.id],
        XML_STATE_ABORTED_PAYLOAD);
        if (xmlResponse is xml) {
            JobInfo|ConnectorError job = getJob(xmlResponse);
            return job;
        } else {
            return xmlResponse;
        }
    }

    # Get CSV insert batch information.
    #
    # + batchId - batch ID 
    # + return - BatchInfo record if successful else ConnectorError occured
    public remote function getBatchInfo(string batchId) returns @tainted BatchInfo|ConnectorError {
        xml|ConnectorError xmlResponse = self.httpBaseClient->getXmlRecord([JOB, self.job.id, BATCH, batchId]);
        if (xmlResponse is xml) {
            BatchInfo|ConnectorError batch = getBatch(xmlResponse);
            return batch;
        } else {
            return xmlResponse;
        }
    }

    # Get information of all batches of CSV insert operator job.
    #
    # + return - BatchInfo record if successful else ConnectorError occured
    public remote function getAllBatches() returns @tainted BatchInfo[]|ConnectorError {
        xml|ConnectorError xmlResponse = self.httpBaseClient->getXmlRecord([JOB, self.job.id, BATCH]);
        if (xmlResponse is xml) {
            BatchInfo[]|ConnectorError batchInfo = getBatchInfoList(xmlResponse);
            return batchInfo;
        } else {
            return xmlResponse;
        }
    }

    # Retrieve the CSV batch request.
    #
    # + batchId - batch ID
    # + return - CSV Batch request if successful else ConnectorError occured
    public remote function getBatchRequest(string batchId) returns @tainted string|ConnectorError {
        return self.httpBaseClient->getCsvRecord([JOB, self.job.id, BATCH, batchId, REQUEST]);
    }

    # Get the results of the batch.
    #
    # + batchId - batch ID
    # + numberOfTries - number of times checking the batch state
    # + waitTime - time between two tries in ms
    # + return - Results array if successful else ConnectorError occured
    public remote function getResult(string batchId, int numberOfTries = 1, int waitTime = 3000) 
        returns @tainted Result[]|ConnectorError {
        return checkBatchStateAndGetResults(getBatchPointer, getResultsPointer, self, batchId, numberOfTries, waitTime);
    }
};
