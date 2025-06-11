'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

/**
 * Workload module for testing AddZakat transaction performance
 */
class AddZakatWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
        this.organizations = [];
        this.zakatTypes = [];
        this.paymentMethods = [];
        this.amounts = [];
        this.muzakkiNames = [
            'Ahmad Sulaiman', 'Fatimah Zahra', 'Muhammad Ridwan', 'Khadijah Aminah',
            'Abdullah Rahman', 'Aisha Safira', 'Umar Farouk', 'Zainab Hasna',
            'Ali Hassan', 'Mariam Salma', 'Yusuf Hakim', 'Ruqayyah Nadia',
            'Ibrahim Malik', 'Hafizah Sari', 'Ismail Firdaus', 'Sakinah Dewi'
        ];
        this.programIds = [
            'PROG-2024-0001', // Bantuan Pendidikan Anak Yatim
            'PROG-2024-0002', // Program Kesehatan Masyarakat
            'PROG-2024-0003', // Bantuan Keluarga Dhuafa
            ''  // No program
        ];
        this.referralCodes = [
            'REF001', 'REF002', 'REF003', 'REF004', ''  // Empty for no referral
        ];
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        
        this.chaincodeId = roundArguments.chaincodeId || 'zakat';
        this.organizations = roundArguments.organizations || ['YDSF Malang', 'YDSF Jatim'];
        this.zakatTypes = roundArguments.zakatTypes || ['maal', 'fitrah'];
        this.paymentMethods = roundArguments.paymentMethods || ['transfer', 'ewallet', 'cash'];
        this.amounts = roundArguments.amounts || [100000, 250000, 500000, 1000000, 2500000];
        
        console.log(`Worker ${workerIndex}: AddZakat workload initialized for chaincode ${this.chaincodeId}`);
    }

    async submitTransaction() {
        this.txIndex++;
        
        // Generate unique zakat ID
        const now = new Date();
        const year = now.getFullYear();
        const month = String(now.getMonth() + 1).padStart(2, '0');
        const orgCode = this.organizations[this.txIndex % this.organizations.length] === 'YDSF Malang' ? 'MLG' : 'JTM';
        const counter = String(this.txIndex).padStart(4, '0');
        const zakatId = `ZKT-YDSF-${orgCode}-${year}${month}-${counter}`;
        
        // Random selection of transaction parameters
        const programId = this.programIds[Math.floor(Math.random() * this.programIds.length)];
        const muzakki = this.muzakkiNames[Math.floor(Math.random() * this.muzakkiNames.length)];
        const amount = this.amounts[Math.floor(Math.random() * this.amounts.length)];
        const zakatType = this.zakatTypes[Math.floor(Math.random() * this.zakatTypes.length)];
        const paymentMethod = this.paymentMethods[Math.floor(Math.random() * this.paymentMethods.length)];
        const organization = this.organizations[Math.floor(Math.random() * this.organizations.length)];
        const referralCode = this.referralCodes[Math.floor(Math.random() * this.referralCodes.length)];

        const request = {
            contractId: this.chaincodeId,
            contractFunction: 'AddZakat',
            contractArguments: [
                zakatId,
                programId,
                muzakki,
                amount.toString(),
                zakatType,
                paymentMethod,
                organization,
                referralCode
            ],
            readOnly: false
        };

        await this.sutAdapter.sendRequests(request);
    }

    async cleanupWorkloadModule() {
        console.log('AddZakat workload finished');
    }
}

module.exports = AddZakatWorkload;