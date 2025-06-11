'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

/**
 * Workload module for testing ValidatePayment transaction performance
 */
class ValidatePaymentWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
        this.admins = [];
        this.pendingZakats = [];
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        
        this.chaincodeId = roundArguments.chaincodeId || 'zakat';
        this.admins = roundArguments.admins || ['AdminOrg1', 'AdminOrg2'];
        
        // Query for pending zakats to validate
        await this.loadPendingZakats();
        
        console.log(`Worker ${workerIndex}: ValidatePayment workload initialized with ${this.pendingZakats.length} pending zakats`);
    }

    async loadPendingZakats() {
        try {
            const request = {
                contractId: this.chaincodeId,
                contractFunction: 'GetZakatByStatus',
                contractArguments: ['pending'],
                readOnly: true
            };

            const response = await this.sutAdapter.sendRequests(request);
            if (response && response.status === 'success' && response.result) {
                this.pendingZakats = JSON.parse(response.result);
                console.log(`Loaded ${this.pendingZakats.length} pending zakats for validation`);
            }
        } catch (error) {
            console.warn('Could not load pending zakats, workload will create test scenarios:', error.message);
            // Fallback: create mock pending zakat IDs
            this.pendingZakats = [];
            for (let i = 1; i <= 50; i++) {
                this.pendingZakats.push({
                    ID: `ZKT-YDSF-MLG-202406-${String(i).padStart(4, '0')}`
                });
            }
        }
    }

    async submitTransaction() {
        this.txIndex++;
        
        if (this.pendingZakats.length === 0) {
            console.warn('No pending zakats available for validation');
            return;
        }

        // Select a random pending zakat
        const zakatIndex = this.txIndex % this.pendingZakats.length;
        const zakatId = this.pendingZakats[zakatIndex].ID;
        
        // Generate receipt number
        const receiptNumber = `INV/2024/${String(Date.now()).slice(-8)}/${String(this.txIndex).padStart(4, '0')}`;
        
        // Random admin selection
        const validatedBy = this.admins[Math.floor(Math.random() * this.admins.length)];

        const request = {
            contractId: this.chaincodeId,
            contractFunction: 'ValidatePayment',
            contractArguments: [
                zakatId,
                receiptNumber,
                validatedBy
            ],
            readOnly: false
        };

        await this.sutAdapter.sendRequests(request);
    }

    async cleanupWorkloadModule() {
        console.log('ValidatePayment workload finished');
    }
}

module.exports = ValidatePaymentWorkload;