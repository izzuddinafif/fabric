'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

/**
 * Workload module for testing mixed operations (realistic usage scenario)
 */
class MixedOperationsWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
        this.addZakatWeight = 40;
        this.validatePaymentWeight = 20;
        this.queryWeight = 40;
        this.pendingZakats = [];
        
        // Shared data pools
        this.organizations = ['YDSF Malang', 'YDSF Jatim'];
        this.zakatTypes = ['maal', 'fitrah'];
        this.paymentMethods = ['transfer', 'ewallet', 'cash'];
        this.amounts = [100000, 250000, 500000, 1000000, 2500000];
        this.muzakkiNames = [
            'Ahmad Sulaiman', 'Fatimah Zahra', 'Muhammad Ridwan', 'Khadijah Aminah',
            'Abdullah Rahman', 'Aisha Safira', 'Umar Farouk', 'Zainab Hasna'
        ];
        this.programIds = ['PROG-2024-0001', 'PROG-2024-0002', 'PROG-2024-0003', ''];
        this.referralCodes = ['REF001', 'REF002', 'REF003', 'REF004', ''];
        this.admins = ['AdminOrg1', 'AdminOrg2'];
        this.queryTypes = [
            'GetAllZakat', 'GetZakatByStatus', 'GetZakatByProgram', 
            'GetAllPrograms', 'GetDailyReport'
        ];
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        
        this.chaincodeId = roundArguments.chaincodeId || 'zakat';
        this.addZakatWeight = roundArguments.addZakatWeight || 40;
        this.validatePaymentWeight = roundArguments.validatePaymentWeight || 20;
        this.queryWeight = roundArguments.queryWeight || 40;
        
        // Initialize pending zakats list
        await this.initializePendingZakats();
        
        console.log(`Worker ${workerIndex}: MixedOperations workload initialized`);
        console.log(`Weights - AddZakat: ${this.addZakatWeight}%, ValidatePayment: ${this.validatePaymentWeight}%, Query: ${this.queryWeight}%`);
    }

    async initializePendingZakats() {
        // Create a pool of potential pending zakat IDs
        for (let i = 1; i <= 100; i++) {
            this.pendingZakats.push(`ZKT-YDSF-MLG-202406-${String(i).padStart(4, '0')}`);
        }
    }

    async submitTransaction() {
        this.txIndex++;
        
        // Determine operation type based on weights
        const random = Math.random() * 100;
        let operation;
        
        if (random < this.addZakatWeight) {
            operation = 'addZakat';
        } else if (random < this.addZakatWeight + this.validatePaymentWeight) {
            operation = 'validatePayment';
        } else {
            operation = 'query';
        }

        let request;

        switch (operation) {
            case 'addZakat':
                request = await this.createAddZakatRequest();
                break;
            case 'validatePayment':
                request = await this.createValidatePaymentRequest();
                break;
            case 'query':
                request = await this.createQueryRequest();
                break;
        }

        if (request) {
            await this.sutAdapter.sendRequests(request);
        }
    }

    async createAddZakatRequest() {
        // Generate unique zakat ID
        const now = new Date();
        const year = now.getFullYear();
        const month = String(now.getMonth() + 1).padStart(2, '0');
        const orgCode = this.organizations[this.txIndex % this.organizations.length] === 'YDSF Malang' ? 'MLG' : 'JTM';
        const counter = String(this.txIndex + 1000).padStart(4, '0'); // Offset to avoid conflicts
        const zakatId = `ZKT-YDSF-${orgCode}-${year}${month}-${counter}`;
        
        // Random selection of parameters
        const programId = this.programIds[Math.floor(Math.random() * this.programIds.length)];
        const muzakki = this.muzakkiNames[Math.floor(Math.random() * this.muzakkiNames.length)];
        const amount = this.amounts[Math.floor(Math.random() * this.amounts.length)];
        const zakatType = this.zakatTypes[Math.floor(Math.random() * this.zakatTypes.length)];
        const paymentMethod = this.paymentMethods[Math.floor(Math.random() * this.paymentMethods.length)];
        const organization = this.organizations[Math.floor(Math.random() * this.organizations.length)];
        const referralCode = this.referralCodes[Math.floor(Math.random() * this.referralCodes.length)];

        return {
            contractId: this.chaincodeId,
            contractFunction: 'AddZakat',
            contractArguments: [
                zakatId, programId, muzakki, amount.toString(),
                zakatType, paymentMethod, organization, referralCode
            ],
            readOnly: false
        };
    }

    async createValidatePaymentRequest() {
        if (this.pendingZakats.length === 0) {
            console.warn('No pending zakats available for validation');
            return null;
        }

        const zakatId = this.pendingZakats[this.txIndex % this.pendingZakats.length];
        const receiptNumber = `INV/2024/${String(Date.now()).slice(-8)}/${String(this.txIndex).padStart(4, '0')}`;
        const validatedBy = this.admins[Math.floor(Math.random() * this.admins.length)];

        return {
            contractId: this.chaincodeId,
            contractFunction: 'ValidatePayment',
            contractArguments: [zakatId, receiptNumber, validatedBy],
            readOnly: false
        };
    }

    async createQueryRequest() {
        const queryType = this.queryTypes[Math.floor(Math.random() * this.queryTypes.length)];
        
        switch (queryType) {
            case 'GetAllZakat':
                return {
                    contractId: this.chaincodeId,
                    contractFunction: 'GetAllZakat',
                    contractArguments: [],
                    readOnly: true
                };

            case 'GetZakatByStatus':
                const statuses = ['pending', 'collected', 'distributed'];
                const status = statuses[Math.floor(Math.random() * statuses.length)];
                return {
                    contractId: this.chaincodeId,
                    contractFunction: 'GetZakatByStatus',
                    contractArguments: [status],
                    readOnly: true
                };

            case 'GetZakatByProgram':
                const programId = this.programIds[Math.floor(Math.random() * (this.programIds.length - 1))]; // Exclude empty
                return {
                    contractId: this.chaincodeId,
                    contractFunction: 'GetZakatByProgram',
                    contractArguments: [programId],
                    readOnly: true
                };

            case 'GetAllPrograms':
                return {
                    contractId: this.chaincodeId,
                    contractFunction: 'GetAllPrograms',
                    contractArguments: [],
                    readOnly: true
                };

            case 'GetDailyReport':
                const dates = ['2024-06-01', '2024-06-02', '2024-06-03', '2024-06-04'];
                const reportDate = dates[Math.floor(Math.random() * dates.length)];
                return {
                    contractId: this.chaincodeId,
                    contractFunction: 'GetDailyReport',
                    contractArguments: [reportDate],
                    readOnly: true
                };

            default:
                return null;
        }
    }

    async cleanupWorkloadModule() {
        console.log('MixedOperations workload finished');
    }
}

module.exports = MixedOperationsWorkload;