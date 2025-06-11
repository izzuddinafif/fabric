'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

/**
 * Workload module for testing various query operations performance
 */
class QueryOperationsWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
        this.queryTypes = [];
        this.queryParameters = {
            statuses: ['pending', 'collected', 'distributed'],
            programIds: ['PROG-2024-0001', 'PROG-2024-0002', 'PROG-2024-0003'],
            referralCodes: ['REF001', 'REF002', 'REF003', 'REF004'],
            muzakkiNames: [
                'Ahmad Sulaiman', 'Fatimah Zahra', 'Muhammad Ridwan', 
                'Khadijah Aminah', 'Abdullah Rahman', 'Aisha Safira'
            ],
            reportDates: [
                '2024-06-01', '2024-06-02', '2024-06-03', '2024-06-04',
                '2024-06-05', '2024-06-06', '2024-06-07', '2024-06-08'
            ]
        };
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        
        this.chaincodeId = roundArguments.chaincodeId || 'zakat';
        this.queryTypes = roundArguments.queryTypes || [
            'GetAllZakat', 
            'GetZakatByStatus', 
            'GetZakatByProgram',
            'GetZakatByOfficer',
            'GetZakatByMuzakki',
            'GetAllPrograms',
            'GetDailyReport'
        ];
        
        console.log(`Worker ${workerIndex}: QueryOperations workload initialized with ${this.queryTypes.length} query types`);
    }

    async submitTransaction() {
        this.txIndex++;
        
        // Select random query type
        const queryType = this.queryTypes[this.txIndex % this.queryTypes.length];
        let request;

        switch (queryType) {
            case 'GetAllZakat':
                request = {
                    contractId: this.chaincodeId,
                    contractFunction: 'GetAllZakat',
                    contractArguments: [],
                    readOnly: true
                };
                break;

            case 'GetZakatByStatus':
                const status = this.queryParameters.statuses[Math.floor(Math.random() * this.queryParameters.statuses.length)];
                request = {
                    contractId: this.chaincodeId,
                    contractFunction: 'GetZakatByStatus',
                    contractArguments: [status],
                    readOnly: true
                };
                break;

            case 'GetZakatByProgram':
                const programId = this.queryParameters.programIds[Math.floor(Math.random() * this.queryParameters.programIds.length)];
                request = {
                    contractId: this.chaincodeId,
                    contractFunction: 'GetZakatByProgram',
                    contractArguments: [programId],
                    readOnly: true
                };
                break;

            case 'GetZakatByOfficer':
                const referralCode = this.queryParameters.referralCodes[Math.floor(Math.random() * this.queryParameters.referralCodes.length)];
                request = {
                    contractId: this.chaincodeId,
                    contractFunction: 'GetZakatByOfficer',
                    contractArguments: [referralCode],
                    readOnly: true
                };
                break;

            case 'GetZakatByMuzakki':
                const muzakkiName = this.queryParameters.muzakkiNames[Math.floor(Math.random() * this.queryParameters.muzakkiNames.length)];
                request = {
                    contractId: this.chaincodeId,
                    contractFunction: 'GetZakatByMuzakki',
                    contractArguments: [muzakkiName],
                    readOnly: true
                };
                break;

            case 'GetAllPrograms':
                request = {
                    contractId: this.chaincodeId,
                    contractFunction: 'GetAllPrograms',
                    contractArguments: [],
                    readOnly: true
                };
                break;

            case 'GetDailyReport':
                const reportDate = this.queryParameters.reportDates[Math.floor(Math.random() * this.queryParameters.reportDates.length)];
                request = {
                    contractId: this.chaincodeId,
                    contractFunction: 'GetDailyReport',
                    contractArguments: [reportDate],
                    readOnly: true
                };
                break;

            default:
                console.warn(`Unknown query type: ${queryType}`);
                return;
        }

        await this.sutAdapter.sendRequests(request);
    }

    async cleanupWorkloadModule() {
        console.log('QueryOperations workload finished');
    }
}

module.exports = QueryOperationsWorkload;