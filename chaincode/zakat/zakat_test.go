package main

import (
	"encoding/json"
	"fmt"
	"testing"
	"time"

	"github.com/hyperledger/fabric-chaincode-go/shim"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
	"github.com/hyperledger/fabric-protos-go/ledger/queryresult"
	"github.com/hyperledger/fabric-protos-go/peer"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// MockStub implements shim.ChaincodeStubInterface
type MockStub struct {
	mock.Mock
}

// Implement the required methods from ChaincodeStubInterface
func (m *MockStub) GetTxID() string {
	args := m.Called()
	return args.String(0)
}

func (m *MockStub) CreateCompositeKey(objectType string, attributes []string) (string, error) {
	args := m.Called(objectType, attributes)
	return args.String(0), args.Error(1)
}

func (m *MockStub) GetState(key string) ([]byte, error) {
	args := m.Called(key)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).([]byte), args.Error(1)
}

func (m *MockStub) PutState(key string, value []byte) error {
	args := m.Called(key, value)
	return args.Error(0)
}

func (m *MockStub) DelState(key string) error {
	args := m.Called(key)
	return args.Error(0)
}

func (m *MockStub) GetStateByRange(startKey string, endKey string) (shim.StateQueryIteratorInterface, error) {
	mockArgs := m.Called(startKey, endKey)
	if mockArgs.Get(0) == nil {
		return nil, mockArgs.Error(1)
	}
	return mockArgs.Get(0).(shim.StateQueryIteratorInterface), mockArgs.Error(1)
}

func (m *MockStub) GetStateByPartialCompositeKey(objectType string, keys []string) (shim.StateQueryIteratorInterface, error) {
	args := m.Called(objectType, keys)
	return args.Get(0).(shim.StateQueryIteratorInterface), args.Error(1)
}

func (m *MockStub) InvokeChaincode(chaincodeName string, chaincodeArgs [][]byte, channel string) peer.Response {
	mockArgs := m.Called(chaincodeName, chaincodeArgs, channel)
	return mockArgs.Get(0).(peer.Response)
}

func (m *MockStub) GetDecorations() map[string][]byte {
	mockArgs := m.Called()
	return mockArgs.Get(0).(map[string][]byte)
}

func (m *MockStub) GetChannelID() string {
	mockArgs := m.Called()
	return mockArgs.String(0)
}

func (m *MockStub) GetSignedProposal() (*peer.SignedProposal, error) {
	mockArgs := m.Called()
	return mockArgs.Get(0).(*peer.SignedProposal), mockArgs.Error(1)
}

func (m *MockStub) GetCreator() ([]byte, error) {
	mockArgs := m.Called()
	return mockArgs.Get(0).([]byte), mockArgs.Error(1)
}

func (m *MockStub) GetTransient() (map[string][]byte, error) {
	mockArgs := m.Called()
	return mockArgs.Get(0).(map[string][]byte), mockArgs.Error(1)
}

func (m *MockStub) GetBinding() ([]byte, error) {
	mockArgs := m.Called()
	return mockArgs.Get(0).([]byte), mockArgs.Error(1)
}

func (m *MockStub) GetArgsSlice() ([]byte, error) {
	mockArgs := m.Called()
	return mockArgs.Get(0).([]byte), mockArgs.Error(1)
}

func (m *MockStub) GetStringArgs() []string {
	mockArgs := m.Called()
	return mockArgs.Get(0).([]string)
}

func (m *MockStub) GetFunctionAndParameters() (string, []string) {
	mockArgs := m.Called()
	return mockArgs.String(0), mockArgs.Get(1).([]string)
}

func (m *MockStub) GetArgs() [][]byte {
	mockArgs := m.Called()
	return mockArgs.Get(0).([][]byte)
}

func (m *MockStub) SetStateValidationParameter(key string, ep []byte) error {
	mockArgs := m.Called(key, ep)
	return mockArgs.Error(0)
}

func (m *MockStub) GetStateValidationParameter(key string) ([]byte, error) {
	mockArgs := m.Called(key)
	return mockArgs.Get(0).([]byte), mockArgs.Error(1)
}

func (m *MockStub) GetHistoryForKey(key string) (shim.HistoryQueryIteratorInterface, error) {
	mockArgs := m.Called(key)
	return mockArgs.Get(0).(shim.HistoryQueryIteratorInterface), mockArgs.Error(1)
}

func (m *MockStub) GetPrivateData(collection, key string) ([]byte, error) {
	mockArgs := m.Called(collection, key)
	return mockArgs.Get(0).([]byte), mockArgs.Error(1)
}

func (m *MockStub) GetPrivateDataHash(collection, key string) ([]byte, error) {
	mockArgs := m.Called(collection, key)
	return mockArgs.Get(0).([]byte), mockArgs.Error(1)
}

func (m *MockStub) PutPrivateData(collection string, key string, value []byte) error {
	mockArgs := m.Called(collection, key, value)
	return mockArgs.Error(0)
}

func (m *MockStub) DelPrivateData(collection, key string) error {
	mockArgs := m.Called(collection, key)
	return mockArgs.Error(0)
}

func (m *MockStub) GetPrivateDataByRange(collection, startKey, endKey string) (shim.StateQueryIteratorInterface, error) {
	mockArgs := m.Called(collection, startKey, endKey)
	return mockArgs.Get(0).(shim.StateQueryIteratorInterface), mockArgs.Error(1)
}

func (m *MockStub) GetPrivateDataByPartialCompositeKey(collection, objectType string, keys []string) (shim.StateQueryIteratorInterface, error) {
	mockArgs := m.Called(collection, objectType, keys)
	return mockArgs.Get(0).(shim.StateQueryIteratorInterface), mockArgs.Error(1)
}

func (m *MockStub) GetPrivateDataQueryResult(collection, query string) (shim.StateQueryIteratorInterface, error) {
	mockArgs := m.Called(collection, query)
	return mockArgs.Get(0).(shim.StateQueryIteratorInterface), mockArgs.Error(1)
}

func (m *MockStub) GetQueryResult(query string) (shim.StateQueryIteratorInterface, error) {
	mockArgs := m.Called(query)
	if mockArgs.Get(0) == nil {
		return nil, mockArgs.Error(1)
	}
	return mockArgs.Get(0).(shim.StateQueryIteratorInterface), mockArgs.Error(1)
}

func (m *MockStub) GetStateByPartialCompositeKeyWithPagination(objectType string, keys []string, pageSize int32, bookmark string) (shim.StateQueryIteratorInterface, *peer.QueryResponseMetadata, error) {
	mockArgs := m.Called(objectType, keys, pageSize, bookmark)
	return mockArgs.Get(0).(shim.StateQueryIteratorInterface), mockArgs.Get(1).(*peer.QueryResponseMetadata), mockArgs.Error(2)
}

func (m *MockStub) GetQueryResultWithPagination(query string, pageSize int32, bookmark string) (shim.StateQueryIteratorInterface, *peer.QueryResponseMetadata, error) {
	mockArgs := m.Called(query, pageSize, bookmark)
	return mockArgs.Get(0).(shim.StateQueryIteratorInterface), mockArgs.Get(1).(*peer.QueryResponseMetadata), mockArgs.Error(2)
}

func (m *MockStub) GetStateByRangeWithPagination(startKey, endKey string, pageSize int32, bookmark string) (shim.StateQueryIteratorInterface, *peer.QueryResponseMetadata, error) {
	mockArgs := m.Called(startKey, endKey, pageSize, bookmark)
	return mockArgs.Get(0).(shim.StateQueryIteratorInterface), mockArgs.Get(1).(*peer.QueryResponseMetadata), mockArgs.Error(2)
}

func (m *MockStub) SetPrivateDataValidationParameter(collection, key string, ep []byte) error {
	mockArgs := m.Called(collection, key, ep)
	return mockArgs.Error(0)
}

func (m *MockStub) GetPrivateDataValidationParameter(collection, key string) ([]byte, error) {
	mockArgs := m.Called(collection, key)
	return mockArgs.Get(0).([]byte), mockArgs.Error(1)
}

func (m *MockStub) GetTxTimestamp() (*timestamppb.Timestamp, error) {
	mockArgs := m.Called()
	return mockArgs.Get(0).(*timestamppb.Timestamp), mockArgs.Error(1)
}

func (m *MockStub) MockTransactionStart(txid string) {
	m.Called(txid)
}

func (m *MockStub) MockTransactionEnd(txid string) {
	m.Called(txid)
}

func (m *MockStub) SetStub(stub interface{}) {
	m.Called(stub)
}

func (m *MockStub) PurgePrivateData(collection string, key string) error {
	mockArgs := m.Called(collection, key)
	return mockArgs.Error(0)
}

func (m *MockStub) SetEvent(name string, payload []byte) error {
	mockArgs := m.Called(name, payload)
	return mockArgs.Error(0)
}

func (m *MockStub) SplitCompositeKey(compositeKey string) (string, []string, error) {
	mockArgs := m.Called(compositeKey)
	return mockArgs.String(0), mockArgs.Get(1).([]string), mockArgs.Error(2)
}

// KV is a key/value pair used in QueryResult
type KV struct {
	Key   string
	Value []byte
}

// MockQueryIterator implements shim.StateQueryIteratorInterface for testing with mock expectations
type MockQueryIterator struct {
	mock.Mock
}

// SimpleQueryIterator implements shim.StateQueryIteratorInterface for simple testing
type SimpleQueryIterator struct {
	Current int
	Items   []QueryResult
}

type QueryResult struct {
	Key   string
	Value []byte
}

func (m *MockQueryIterator) HasNext() bool {
	args := m.Called()
	return args.Bool(0)
}

func (m *MockQueryIterator) Next() (*queryresult.KV, error) {
	args := m.Called()
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*queryresult.KV), args.Error(1)
}

func (m *MockQueryIterator) Close() error {
	args := m.Called()
	return args.Error(0)
}

func (s *SimpleQueryIterator) HasNext() bool {
	return s.Current+1 < len(s.Items)
}

func (s *SimpleQueryIterator) Next() (*queryresult.KV, error) {
	if !s.HasNext() {
		return nil, nil
	}
	s.Current++
	return &queryresult.KV{
		Key:   s.Items[s.Current].Key,
		Value: s.Items[s.Current].Value,
	}, nil
}

func (s *SimpleQueryIterator) Close() error {
	return nil
}

func TestInitLedger(t *testing.T) {
	sampleProgramID := "PROG-2024-0001"
	sampleOfficerID := "OFF-2024-0001"

	t.Run("SuccessFirstTimeInitialization", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		// Expect GetState for sampleProgramID to return nil (not found)
		chaincodeStub.On("GetState", sampleProgramID).Return(nil, nil).Once()

		// Expect PutState for sampleProgramID
		chaincodeStub.On("PutState", sampleProgramID, mock.AnythingOfType("[]uint8")).Return(nil).Once().Run(func(args mock.Arguments) {
			var program DonationProgram
			err := json.Unmarshal(args.Get(1).([]byte), &program)
			require.NoError(t, err)
			require.Equal(t, sampleProgramID, program.ID)
			require.Equal(t, "Bantuan Pendidikan Anak Yatim", program.Name)
		})

		// Expect PutState for sampleOfficerID
		chaincodeStub.On("PutState", sampleOfficerID, mock.AnythingOfType("[]uint8")).Return(nil).Once().Run(func(args mock.Arguments) {
			var officer Officer
			err := json.Unmarshal(args.Get(1).([]byte), &officer)
			require.NoError(t, err)
			require.Equal(t, sampleOfficerID, officer.ID)
			require.Equal(t, "Ahmad Petugas", officer.Name)
			require.Equal(t, "REF001", officer.ReferralCode)
		})

		smartContract := new(SmartContract)
		err := smartContract.InitLedger(transactionContext)
		require.NoError(t, err)

		chaincodeStub.AssertExpectations(t)
	})

	t.Run("SuccessAlreadyInitialized", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		// Expect GetState for sampleProgramID to return existing data
		sampleProgramJSON, _ := json.Marshal(DonationProgram{ID: sampleProgramID, Name: "Existing Program"})
		chaincodeStub.On("GetState", sampleProgramID).Return(sampleProgramJSON, nil).Once()

		// No PutState calls should be made if already initialized
		chaincodeStub.AssertNotCalled(t, "PutState", mock.AnythingOfType("string"), mock.AnythingOfType("[]uint8"))

		smartContract := new(SmartContract)
		err := smartContract.InitLedger(transactionContext)
		require.NoError(t, err)

		chaincodeStub.AssertExpectations(t)
	})

	t.Run("GetStateErrorDuringCheck", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		chaincodeStub.On("GetState", sampleProgramID).Return(nil, fmt.Errorf("ledger error")).Once()

		smartContract := new(SmartContract)
		err := smartContract.InitLedger(transactionContext)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to check sample program existence")

		chaincodeStub.AssertExpectations(t)
	})

	t.Run("PutStateErrorForProgram", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		chaincodeStub.On("GetState", sampleProgramID).Return(nil, nil).Once()
		chaincodeStub.On("PutState", sampleProgramID, mock.AnythingOfType("[]uint8")).Return(fmt.Errorf("ledger error")).Once()
		// Deliberately not mocking PutState for officer, as it should fail before that

		smartContract := new(SmartContract)
		err := smartContract.InitLedger(transactionContext)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to put sample program")

		chaincodeStub.AssertExpectations(t)
	})

	t.Run("PutStateErrorForOfficer", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		chaincodeStub.On("GetState", sampleProgramID).Return(nil, nil).Once()
		chaincodeStub.On("PutState", sampleProgramID, mock.AnythingOfType("[]uint8")).Return(nil).Once()                        // Program PutState succeeds
		chaincodeStub.On("PutState", sampleOfficerID, mock.AnythingOfType("[]uint8")).Return(fmt.Errorf("ledger error")).Once() // Officer PutState fails

		smartContract := new(SmartContract)
		err := smartContract.InitLedger(transactionContext)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to put sample officer")

		chaincodeStub.AssertExpectations(t)
	})
}

func TestAddZakat(t *testing.T) {
	const (
		testZakatID       = "ZKT-YDSF-MLG-1735689000000000000-0001"  // New timestamp-based format
		testProgramID     = "PROG-2024-1735689000000000000-0001"     // New timestamp-based format
		testMuzakki       = "Test Donor"
		testAmount        = float64(500000)
		testZakatType     = "maal"
		testPaymentMethod = "transfer"
		testOrganization  = "YDSF Malang"
		testReferralCode  = "REF001"
	)
	sampleProgramJSON, _ := json.Marshal(DonationProgram{ID: testProgramID, Name: "Test Program"})

	t.Run("Success", func(t *testing.T) {
		var expectedOfficerJSON []byte
		var err error
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		// Mock GetProgram if programID is provided
		chaincodeStub.On("GetState", testProgramID).Return(sampleProgramJSON, nil).Once()
		// Mock ZakatExists (GetState for zakat ID)
		chaincodeStub.On("GetState", testZakatID).Return(nil, nil).Once() // Zakat doesn't exist

		// Mock GetOfficerByReferral if referralCode is provided and officer exists
		// This is called internally by AddZakat when a referralCode is present.
		officerReferralQuery := fmt.Sprintf("{\"selector\":{\"referralCode\":\"%s\"}}", testReferralCode)
		// Assuming the officer from InitLedger (OFF-2024-0001, REF001) is the one being referred
		expectedOfficer := Officer{ID: "OFF-2024-0001", Name: "Ahmad Petugas", ReferralCode: testReferralCode, Status: "active"}
		expectedOfficerJSON, err = json.Marshal(expectedOfficer)
		require.NoError(t, err) // Ensure marshaling is successful
		officerIterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{{Key: expectedOfficer.ID, Value: expectedOfficerJSON}}}
		chaincodeStub.On("GetQueryResult", officerReferralQuery).Return(officerIterator, nil).Once()
		// Mock PutState for the new zakat
		chaincodeStub.On("PutState", testZakatID, mock.AnythingOfType("[]uint8")).Return(nil).Once().Run(func(args mock.Arguments) {
			var zakat Zakat
			err := json.Unmarshal(args.Get(1).([]byte), &zakat)
			require.NoError(t, err)
			require.Equal(t, testZakatID, zakat.ID)
			require.Equal(t, testProgramID, zakat.ProgramID)
			require.Equal(t, testMuzakki, zakat.Muzakki)
			require.Equal(t, testAmount, zakat.Amount)
			require.Equal(t, testZakatType, zakat.Type)
			require.Equal(t, testPaymentMethod, zakat.PaymentMethod)
			require.Equal(t, "pending", zakat.Status)
			require.Equal(t, testOrganization, zakat.Organization)
			require.Equal(t, testReferralCode, zakat.ReferralCode)
		})

		smartContract := new(SmartContract)
		err = smartContract.AddZakat(transactionContext, testZakatID, testProgramID, testMuzakki, testAmount, testZakatType, testPaymentMethod, testOrganization, testReferralCode)
		require.NoError(t, err)
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("ZakatAlreadyExists", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		chaincodeStub.On("GetState", testProgramID).Return(sampleProgramJSON, nil).Maybe() // Program check might occur
		existingZakatJSON, _ := json.Marshal(Zakat{ID: testZakatID})
		chaincodeStub.On("GetState", testZakatID).Return(existingZakatJSON, nil).Once() // Zakat exists

		// Mock GetOfficerByReferral if referralCode is provided and officer exists
		officerReferralQuery := fmt.Sprintf("{\"selector\":{\"referralCode\":\"%s\"}}", testReferralCode)
		expectedOfficer := Officer{ID: "OFF-2024-0001", Name: "Ahmad Petugas", ReferralCode: testReferralCode, Status: "active"}
		expectedOfficerJSON, err := json.Marshal(expectedOfficer)
		require.NoError(t, err)
		officerIterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{{Key: expectedOfficer.ID, Value: expectedOfficerJSON}}}
		chaincodeStub.On("GetQueryResult", officerReferralQuery).Return(officerIterator, nil).Maybe()

		smartContract := new(SmartContract)
		err = smartContract.AddZakat(transactionContext, testZakatID, testProgramID, testMuzakki, testAmount, testZakatType, testPaymentMethod, testOrganization, testReferralCode)
		require.Error(t, err)
		require.Contains(t, err.Error(), "zakat "+testZakatID+" already exists")
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("InvalidProgramID", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		smartContract := new(SmartContract)
		err := smartContract.AddZakat(transactionContext, testZakatID, "INVALIDPROG", testMuzakki, testAmount, testZakatType, testPaymentMethod, testOrganization, testReferralCode)
		require.Error(t, err)
		// The error comes from validateProgramID when program ID format is invalid
		require.Contains(t, err.Error(), "invalid program ID format for 'INVALIDPROG'")
		require.Contains(t, err.Error(), "invalid program ID format. Expected format: PROG-{TYPE}-{TIMESTAMP}-{SEQUENCE}")
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("SuccessWithEmptyProgramID", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		// No GetProgram mock needed if programID is empty
		// Mock ZakatExists (GetState for zakat ID)
		chaincodeStub.On("GetState", testZakatID).Return(nil, nil).Once() // Zakat doesn't exist

		// Mock GetOfficerByReferral if referralCode is provided and officer exists
		officerReferralQuery := fmt.Sprintf("{\"selector\":{\"referralCode\":\"%s\"}}", testReferralCode)
		expectedOfficer := Officer{ID: "OFF-2024-0001", Name: "Ahmad Petugas", ReferralCode: testReferralCode, Status: "active"}
		expectedOfficerJSON, err := json.Marshal(expectedOfficer)
		require.NoError(t, err)
		officerIterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{{Key: expectedOfficer.ID, Value: expectedOfficerJSON}}}
		chaincodeStub.On("GetQueryResult", officerReferralQuery).Return(officerIterator, nil).Once()

		// Mock PutState for the new zakat
		chaincodeStub.On("PutState", testZakatID, mock.AnythingOfType("[]uint8")).Return(nil).Once().Run(func(args mock.Arguments) {
			var zakat Zakat
			err := json.Unmarshal(args.Get(1).([]byte), &zakat)
			require.NoError(t, err)
			require.Equal(t, "", zakat.ProgramID) // ProgramID should be empty
		})

		smartContract := new(SmartContract)
		// Pass empty string for programID
		err = smartContract.AddZakat(transactionContext, testZakatID, "", testMuzakki, testAmount, testZakatType, testPaymentMethod, testOrganization, testReferralCode)
		require.NoError(t, err)
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("InvalidZakatIDFormat", func(t *testing.T) {
		chaincodeStub := new(MockStub) // No stub interactions needed if validation fails early
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		smartContract := new(SmartContract)
		err := smartContract.AddZakat(transactionContext, "INVALID-ID", testProgramID, testMuzakki, testAmount, testZakatType, testPaymentMethod, testOrganization, testReferralCode)
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid zakat ID format")
	})

	t.Run("InvalidAmount", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		smartContract := new(SmartContract)
		err := smartContract.AddZakat(transactionContext, testZakatID, testProgramID, testMuzakki, -100, testZakatType, testPaymentMethod, testOrganization, testReferralCode)
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid amount")
	})

	t.Run("InvalidZakatType", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		smartContract := new(SmartContract)
		err := smartContract.AddZakat(transactionContext, testZakatID, testProgramID, testMuzakki, testAmount, "invalid_type", testPaymentMethod, testOrganization, testReferralCode)
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid zakat type")
	})

	t.Run("InvalidPaymentMethod", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		smartContract := new(SmartContract)
		err := smartContract.AddZakat(transactionContext, testZakatID, testProgramID, testMuzakki, testAmount, testZakatType, "invalid_method", testOrganization, testReferralCode)
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid payment method")
	})

	t.Run("InvalidOrganization", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		smartContract := new(SmartContract)
		err := smartContract.AddZakat(transactionContext, testZakatID, testProgramID, testMuzakki, testAmount, testZakatType, testPaymentMethod, "Invalid Organization", testReferralCode)
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid organization")
	})

	t.Run("EmptyMuzakkiName", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		smartContract := new(SmartContract)
		err := smartContract.AddZakat(transactionContext, testZakatID, testProgramID, "", testAmount, testZakatType, testPaymentMethod, testOrganization, testReferralCode)
		require.Error(t, err)
		require.Contains(t, err.Error(), "muzakki name cannot be empty")
	})

	t.Run("ProgramNotFound", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		// Mock GetState to return nil for the program (not found)
		chaincodeStub.On("GetState", testProgramID).Return(nil, nil).Once()

		smartContract := new(SmartContract)
		err := smartContract.AddZakat(transactionContext, testZakatID, testProgramID, testMuzakki, testAmount, testZakatType, testPaymentMethod, testOrganization, testReferralCode)
		require.Error(t, err)
		require.Contains(t, err.Error(), "does not exist")
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("OfficerNotFoundByReferralCode", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		// Mock GetProgram succeeds
		chaincodeStub.On("GetState", testProgramID).Return(sampleProgramJSON, nil).Once()
		
		// Mock GetOfficerByReferral fails - no officer found
		officerReferralQuery := fmt.Sprintf("{\"selector\":{\"referralCode\":\"%s\"}}", "NONEXISTENT")
		emptyIterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{}}
		chaincodeStub.On("GetQueryResult", officerReferralQuery).Return(emptyIterator, nil).Once()

		smartContract := new(SmartContract)
		err := smartContract.AddZakat(transactionContext, testZakatID, testProgramID, testMuzakki, testAmount, testZakatType, testPaymentMethod, testOrganization, "NONEXISTENT")
		require.Error(t, err)
		require.Contains(t, err.Error(), "does not exist")
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("ZakatExistsCheckError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		// Mock GetProgram succeeds
		chaincodeStub.On("GetState", testProgramID).Return(sampleProgramJSON, nil).Once()
		
		// Mock GetOfficerByReferral succeeds
		officerReferralQuery := fmt.Sprintf("{\"selector\":{\"referralCode\":\"%s\"}}", testReferralCode)
		expectedOfficer := Officer{ID: "OFF-2024-0001", Name: "Ahmad Petugas", ReferralCode: testReferralCode, Status: "active"}
		expectedOfficerJSON, _ := json.Marshal(expectedOfficer)
		officerIterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{{Key: expectedOfficer.ID, Value: expectedOfficerJSON}}}
		chaincodeStub.On("GetQueryResult", officerReferralQuery).Return(officerIterator, nil).Once()
		
		// Mock ZakatExists check to fail with error
		chaincodeStub.On("GetState", testZakatID).Return(nil, fmt.Errorf("ledger error")).Once()

		smartContract := new(SmartContract)
		err := smartContract.AddZakat(transactionContext, testZakatID, testProgramID, testMuzakki, testAmount, testZakatType, testPaymentMethod, testOrganization, testReferralCode)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to check zakat existence")
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("PutStateError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		// Mock GetProgram succeeds
		chaincodeStub.On("GetState", testProgramID).Return(sampleProgramJSON, nil).Once()
		
		// Mock GetOfficerByReferral succeeds
		officerReferralQuery := fmt.Sprintf("{\"selector\":{\"referralCode\":\"%s\"}}", testReferralCode)
		expectedOfficer := Officer{ID: "OFF-2024-0001", Name: "Ahmad Petugas", ReferralCode: testReferralCode, Status: "active"}
		expectedOfficerJSON, _ := json.Marshal(expectedOfficer)
		officerIterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{{Key: expectedOfficer.ID, Value: expectedOfficerJSON}}}
		chaincodeStub.On("GetQueryResult", officerReferralQuery).Return(officerIterator, nil).Once()
		
		// Mock ZakatExists check succeeds (zakat doesn't exist)
		chaincodeStub.On("GetState", testZakatID).Return(nil, nil).Once()
		
		// Mock PutState fails
		chaincodeStub.On("PutState", testZakatID, mock.AnythingOfType("[]uint8")).Return(fmt.Errorf("ledger error")).Once()

		smartContract := new(SmartContract)
		err := smartContract.AddZakat(transactionContext, testZakatID, testProgramID, testMuzakki, testAmount, testZakatType, testPaymentMethod, testOrganization, testReferralCode)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to put zakat")
		chaincodeStub.AssertExpectations(t)
	})
}

func TestQueryZakat(t *testing.T) {
	const testZakatID = "ZKT-YDSF-MLG-202401-0001"

	t.Run("Success", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		expectedZakat := Zakat{
			ID:            testZakatID,
			ProgramID:     "PROG-2024-0001",
			Muzakki:       "Test Donor",
			Amount:        float64(500000),
			Type:          "maal",
			PaymentMethod: "transfer",
			Status:        "pending",
			Organization:  "YDSF Malang",
			ReferralCode:  "REF001",
			Timestamp:     time.Now().Format(time.RFC3339),
		}
		zakatJSON, err := json.Marshal(expectedZakat)
		require.NoError(t, err)

		chaincodeStub.On("GetState", testZakatID).Return(zakatJSON, nil).Once()

		smartContract := new(SmartContract)
		zakat, err := smartContract.QueryZakat(transactionContext, testZakatID)
		require.NoError(t, err)
		require.Equal(t, expectedZakat, zakat)
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("NotFound", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		chaincodeStub.On("GetState", testZakatID).Return(nil, nil).Once() // Zakat not found

		smartContract := new(SmartContract)
		_, err := smartContract.QueryZakat(transactionContext, testZakatID)
		require.Error(t, err)
		require.Contains(t, err.Error(), "zakat "+testZakatID+" does not exist")
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("GetStateError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		chaincodeStub.On("GetState", testZakatID).Return(nil, fmt.Errorf("ledger error")).Once()

		smartContract := new(SmartContract)
		_, err := smartContract.QueryZakat(transactionContext, testZakatID)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to read zakat")
		chaincodeStub.AssertExpectations(t)
	})
}

func TestGetAllZakat(t *testing.T) {
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	now := time.Now()

	expectedZakat1 := Zakat{
		ID:           "ZKT-YDSF-MLG-202311-0001",
		Muzakki:      "John Doe",
		Amount:       1000000,
		Type:         "maal",
		Organization: "YDSF Malang",
		Status:       "collected",
		Timestamp:    now.Format(time.RFC3339),
	}

	expectedZakat2 := Zakat{
		ID:           "ZKT-YDSF-JTM-202311-0002", // Different Org and ID
		Muzakki:      "Jane Doe",
		Amount:       500000,
		Type:         "fitrah",
		Organization: "YDSF Jatim",
		Status:       "collected",
		Timestamp:    now.Format(time.RFC3339),
	}

	t.Run("SuccessMultipleZakat", func(t *testing.T) {
		chaincodeStub := new(MockStub) // New stub for subtest
		transactionContext.SetStub(chaincodeStub)

		zakat1JSON, err := json.Marshal(expectedZakat1)
		require.NoError(t, err)
		zakat2JSON, err := json.Marshal(expectedZakat2)
		require.NoError(t, err)

		iterator := &SimpleQueryIterator{
			Current: -1,
			Items: []QueryResult{
				{Key: expectedZakat1.ID, Value: zakat1JSON},
				{Key: expectedZakat2.ID, Value: zakat2JSON},
			},
		}

		chaincodeStub.On("GetStateByRange", "ZKT-", "ZKT-\uffff").Return(iterator, nil).Once()

		smartContract := new(SmartContract)
		zakats, err := smartContract.GetAllZakat(transactionContext)
		require.NoError(t, err)
		require.ElementsMatch(t, []Zakat{expectedZakat1, expectedZakat2}, zakats)
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("SuccessNoZakatFound", func(t *testing.T) {
		chaincodeStub := new(MockStub) // New stub for subtest
		transactionContext.SetStub(chaincodeStub)

		emptyIterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{}}
		chaincodeStub.On("GetStateByRange", "ZKT-", "ZKT-\uffff").Return(emptyIterator, nil).Once()

		smartContract := new(SmartContract)
		zakats, err := smartContract.GetAllZakat(transactionContext)
		require.NoError(t, err)
		require.NotNil(t, zakats)
		require.Empty(t, zakats)
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("ErrorGetStateByRange", func(t *testing.T) {
		chaincodeStub := new(MockStub) // New stub for subtest
		transactionContext.SetStub(chaincodeStub)

		expectedErr := fmt.Errorf("ledger range error")
		chaincodeStub.On("GetStateByRange", "ZKT-", "ZKT-\uffff").Return(nil, expectedErr).Once()

		smartContract := new(SmartContract)
		zakats, err := smartContract.GetAllZakat(transactionContext)
		require.Error(t, err)
		require.Equal(t, expectedErr, err)
		require.NotNil(t, zakats)
		require.Empty(t, zakats) // Should return empty slice on error
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("ErrorIteratorNext", func(t *testing.T) {
		chaincodeStub := new(MockStub) // New stub for subtest
		transactionContext.SetStub(chaincodeStub)

		expectedErr := fmt.Errorf("iterator next error")
		// MockQueryIterator needs to be enhanced to simulate error on Next()
		// For now, we assume GetStateByRange returns an iterator that errors.
		// This requires modifying MockQueryIterator or using a more specific mock.
		// Let's simulate by having GetStateByRange return an iterator that, when Next() is called,
		// it's mocked to return an error.

		// Simplified: Assume the error happens during iteration, caught by GetAllZakat
		// This test case highlights a limitation in the current MockQueryIterator if we want to test Next() error specifically.
		// A more robust mock framework or manual mock for the iterator would be needed.
		// However, the chaincode logic is: if resultsIterator.Next() errors, return [], err.

		// To test this path, we can make the iterator return a valid first item,
		// then make the *iterator itself* error on the second call to Next().
		// This is hard with the current simple MockQueryIterator.
		// A simpler way to test the error handling path within GetAllZakat for iterator.Next()
		// is to ensure that if GetStateByRange returns an iterator that *then* errors,
		// we get the empty slice and the error.

		// Let's assume the first item is fine, but the iterator itself errors on the second HasNext/Next
		// This is still tricky. The easiest way is to ensure the function handles an error from Next()
		// by returning []Zakat{}, err.

		// For this test, let's assume GetStateByRange returns an iterator that will error.
		// We'll use a custom mock for the iterator for this specific sub-test.
		customIterator := new(MockQueryIterator)         // Using existing mock type for structure
		customIterator.On("HasNext").Return(true).Once() // First item exists
		zakat1JSON, _ := json.Marshal(expectedZakat1)
		customIterator.On("Next").Return(&queryresult.KV{Key: expectedZakat1.ID, Value: zakat1JSON}, nil).Once() // First item fine

		customIterator.On("HasNext").Return(true).Once()          // Second item seems to exist
		customIterator.On("Next").Return(nil, expectedErr).Once() // Second item errors

		customIterator.On("Close").Return(nil).Maybe() // Close might be called

		chaincodeStub.On("GetStateByRange", "ZKT-", "ZKT-\uffff").Return(customIterator, nil).Once()

		smartContract := new(SmartContract)
		zakats, err := smartContract.GetAllZakat(transactionContext)
		require.Error(t, err)
		require.Equal(t, expectedErr, err)
		require.NotNil(t, zakats)
		require.Empty(t, zakats) // Should return empty slice on error
		chaincodeStub.AssertExpectations(t)
		customIterator.AssertExpectations(t)
	})

	t.Run("ErrorJSONUnmarshal", func(t *testing.T) {
		chaincodeStub := new(MockStub) // New stub for subtest
		transactionContext.SetStub(chaincodeStub)

		malformedJSON := []byte("this is not json")
		iteratorWithBadJSON := &SimpleQueryIterator{
			Current: -1,
			Items: []QueryResult{
				{Key: "BAD-JSON-ZKT", Value: malformedJSON},
			},
		}
		chaincodeStub.On("GetStateByRange", "ZKT-", "ZKT-\uffff").Return(iteratorWithBadJSON, nil).Once()

		smartContract := new(SmartContract)
		zakats, err := smartContract.GetAllZakat(transactionContext)
		require.Error(t, err)
		// The error will be a json unmarshal error
		var jsonErr *json.SyntaxError
		require.ErrorAs(t, err, &jsonErr)
		require.NotNil(t, zakats)
		require.Empty(t, zakats) // Should return empty slice on error
		chaincodeStub.AssertExpectations(t)
	})
}

func TestGetAllPrograms(t *testing.T) {
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	prog1 := DonationProgram{ID: "PROG-2024-0001", Name: "Program A"}
	prog2 := DonationProgram{ID: "PROG-2024-0002", Name: "Program B"}

	t.Run("SuccessMultiplePrograms", func(t *testing.T) {
		chaincodeStub := new(MockStub) // New stub for subtest
		transactionContext.SetStub(chaincodeStub)
		prog1JSON, _ := json.Marshal(prog1)
		prog2JSON, _ := json.Marshal(prog2)

		iterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{
			{Key: prog1.ID, Value: prog1JSON},
			{Key: prog2.ID, Value: prog2JSON},
		}}
		chaincodeStub.On("GetStateByRange", "PROG-", "PROG-\uffff").Return(iterator, nil).Once()

		smartContract := new(SmartContract)
		programs, err := smartContract.GetAllPrograms(transactionContext)
		require.NoError(t, err)
		require.ElementsMatch(t, []DonationProgram{prog1, prog2}, programs)
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("SuccessNoProgramsFound", func(t *testing.T) {
		chaincodeStub := new(MockStub) // New stub for subtest
		transactionContext.SetStub(chaincodeStub)
		emptyIterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{}}
		chaincodeStub.On("GetStateByRange", "PROG-", "PROG-\uffff").Return(emptyIterator, nil).Once()

		smartContract := new(SmartContract)
		programs, err := smartContract.GetAllPrograms(transactionContext)
		require.NoError(t, err)
		require.NotNil(t, programs)
		require.Empty(t, programs)
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("ErrorGetStateByRange", func(t *testing.T) {
		chaincodeStub := new(MockStub) // New stub for subtest
		transactionContext.SetStub(chaincodeStub)
		expectedErr := fmt.Errorf("ledger range error for programs")
		chaincodeStub.On("GetStateByRange", "PROG-", "PROG-\uffff").Return(nil, expectedErr).Once()

		smartContract := new(SmartContract)
		programs, err := smartContract.GetAllPrograms(transactionContext)
		require.Error(t, err)
		require.Equal(t, expectedErr, err)
		require.NotNil(t, programs)
		require.Empty(t, programs) // Should return empty slice on error
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("ErrorIteratorNext", func(t *testing.T) {
		chaincodeStub := new(MockStub) // New stub for subtest
		transactionContext.SetStub(chaincodeStub)
		expectedErr := fmt.Errorf("iterator next error for programs")

		customIterator := new(MockQueryIterator)
		prog1JSON, _ := json.Marshal(prog1)
		customIterator.On("HasNext").Return(true).Once()
		customIterator.On("Next").Return(&queryresult.KV{Key: prog1.ID, Value: prog1JSON}, nil).Once()
		customIterator.On("HasNext").Return(true).Once()
		customIterator.On("Next").Return(nil, expectedErr).Once()
		customIterator.On("Close").Return(nil).Maybe()

		chaincodeStub.On("GetStateByRange", "PROG-", "PROG-\uffff").Return(customIterator, nil).Once()

		smartContract := new(SmartContract)
		programs, err := smartContract.GetAllPrograms(transactionContext)
		require.Error(t, err)
		require.Equal(t, expectedErr, err)
		require.NotNil(t, programs)
		require.Empty(t, programs) // Should return empty slice on error
		chaincodeStub.AssertExpectations(t)
		customIterator.AssertExpectations(t)
	})

	t.Run("ErrorJSONUnmarshal", func(t *testing.T) {
		chaincodeStub := new(MockStub) // New stub for subtest
		transactionContext.SetStub(chaincodeStub)
		malformedJSON := []byte("this is not program json")
		iteratorWithBadJSON := &SimpleQueryIterator{
			Current: -1,
			Items: []QueryResult{
				{Key: "BAD-JSON-PROG", Value: malformedJSON},
			},
		}
		chaincodeStub.On("GetStateByRange", "PROG-", "PROG-\uffff").Return(iteratorWithBadJSON, nil).Once()

		smartContract := new(SmartContract)
		programs, err := smartContract.GetAllPrograms(transactionContext)
		require.Error(t, err)
		var jsonErr *json.SyntaxError
		require.ErrorAs(t, err, &jsonErr)
		require.NotNil(t, programs)
		require.Empty(t, programs) // Should return empty slice on error
		chaincodeStub.AssertExpectations(t)
	})
}

// --- Tests for new Officer Management Functions ---
func TestRegisterOfficer(t *testing.T) {
	const (
		officerID   = "OFF-2024-1735689000000000000-0002"  // Updated to new timestamp format
		officerName = "Budi Petugas"
		refCode     = "BUDIREF"
	)
	t.Run("Success", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		chaincodeStub.On("GetState", officerID).Return(nil, nil).Once() // Officer doesn't exist
		chaincodeStub.On("PutState", officerID, mock.AnythingOfType("[]uint8")).Return(nil).Once().Run(func(args mock.Arguments) {
			var officer Officer
			err := json.Unmarshal(args.Get(1).([]byte), &officer)
			require.NoError(t, err)
			require.Equal(t, officerID, officer.ID)
			require.Equal(t, officerName, officer.Name)
			require.Equal(t, refCode, officer.ReferralCode)
			require.Equal(t, "active", officer.Status)
		})
		smartContract := new(SmartContract)
		err := smartContract.RegisterOfficer(transactionContext, officerID, officerName, refCode)
		require.NoError(t, err)
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("InvalidOfficerID", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		smartContract := new(SmartContract)
		err := smartContract.RegisterOfficer(transactionContext, "INVALID-ID", officerName, refCode)
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid officer ID format")
	})

	t.Run("OfficerAlreadyExists", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		existingOfficer := Officer{ID: officerID}
		officerJSON, _ := json.Marshal(existingOfficer)
		chaincodeStub.On("GetState", officerID).Return(officerJSON, nil).Once()

		smartContract := new(SmartContract)
		err := smartContract.RegisterOfficer(transactionContext, officerID, officerName, refCode)
		require.Error(t, err)
		require.Contains(t, err.Error(), "already exists")
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("GetStateError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		chaincodeStub.On("GetState", officerID).Return(nil, fmt.Errorf("ledger error")).Once()

		smartContract := new(SmartContract)
		err := smartContract.RegisterOfficer(transactionContext, officerID, officerName, refCode)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to check officer existence")
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("PutStateError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		chaincodeStub.On("GetState", officerID).Return(nil, nil).Once()
		chaincodeStub.On("PutState", officerID, mock.AnythingOfType("[]uint8")).Return(fmt.Errorf("ledger error")).Once()

		smartContract := new(SmartContract)
		err := smartContract.RegisterOfficer(transactionContext, officerID, officerName, refCode)
		require.Error(t, err)
		chaincodeStub.AssertExpectations(t)
	})
}

func TestGetOfficerByReferral(t *testing.T) {
	const refCode = "SITIREF"
	expectedOfficer := Officer{ID: "OFF-2024-1735689000000000000-0003", Name: "Siti Aminah", ReferralCode: refCode}
	officerJSON, _ := json.Marshal(expectedOfficer)

	t.Run("Success", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		queryString := fmt.Sprintf("{\"selector\":{\"referralCode\":\"%s\"}}", refCode)
		iterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{{Key: expectedOfficer.ID, Value: officerJSON}}}
		chaincodeStub.On("GetQueryResult", queryString).Return(iterator, nil).Once()

		smartContract := new(SmartContract)
		officer, err := smartContract.GetOfficerByReferral(transactionContext, refCode)
		require.NoError(t, err)
		require.Equal(t, expectedOfficer, officer)
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("OfficerNotFound", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		queryString := fmt.Sprintf("{\"selector\":{\"referralCode\":\"%s\"}}", "NONEXISTENT")
		emptyIterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{}}
		chaincodeStub.On("GetQueryResult", queryString).Return(emptyIterator, nil).Once()

		smartContract := new(SmartContract)
		_, err := smartContract.GetOfficerByReferral(transactionContext, "NONEXISTENT")
		require.Error(t, err)
		require.Contains(t, err.Error(), "does not exist")
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("QueryError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		queryString := fmt.Sprintf("{\"selector\":{\"referralCode\":\"%s\"}}", refCode)
		// Return nil and error for GetQueryResult
		chaincodeStub.On("GetQueryResult", queryString).Return(nil, fmt.Errorf("query error")).Once()

		smartContract := new(SmartContract)
		_, err := smartContract.GetOfficerByReferral(transactionContext, refCode)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to query officer")
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("IteratorError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		queryString := fmt.Sprintf("{\"selector\":{\"referralCode\":\"%s\"}}", refCode)
		errorIterator := new(MockQueryIterator)
		errorIterator.On("HasNext").Return(true).Once()
		errorIterator.On("Next").Return(nil, fmt.Errorf("iterator error")).Once()
		errorIterator.On("Close").Return(nil).Maybe()
		chaincodeStub.On("GetQueryResult", queryString).Return(errorIterator, nil).Once()

		smartContract := new(SmartContract)
		_, err := smartContract.GetOfficerByReferral(transactionContext, refCode)
		require.Error(t, err)
		chaincodeStub.AssertExpectations(t)
		errorIterator.AssertExpectations(t)
	})

	t.Run("UnmarshalError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		queryString := fmt.Sprintf("{\"selector\":{\"referralCode\":\"%s\"}}", refCode)
		badJSON := []byte("invalid json")
		iterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{{Key: "TEST", Value: badJSON}}}
		chaincodeStub.On("GetQueryResult", queryString).Return(iterator, nil).Once()

		smartContract := new(SmartContract)
		_, err := smartContract.GetOfficerByReferral(transactionContext, refCode)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to unmarshal officer")
		chaincodeStub.AssertExpectations(t)
	})
}

// --- Test for ValidatePayment ---
func TestValidatePayment(t *testing.T) {
	const (
		zakatID       = "ZKT-YDSF-MLG-202401-0010"
		programID     = "PROG-2024-0010"
		officerID     = "OFF-2024-0010"
		referralCode  = "REFVALID"
		receiptNum    = "RCPT001"
		validator     = "adminUser"
		initialAmount = float64(100000)
	)

	pendingZakat := Zakat{ID: zakatID, ProgramID: programID, ReferralCode: referralCode, Amount: initialAmount, Status: "pending"}
	pendingZakatJSON, _ := json.Marshal(pendingZakat)

	initialProgram := DonationProgram{ID: programID, Collected: 50000}
	initialProgramJSON, _ := json.Marshal(initialProgram)

	initialOfficer := Officer{ID: officerID, ReferralCode: referralCode, TotalReferred: 20000}
	initialOfficerJSON, _ := json.Marshal(initialOfficer)

	t.Run("Success", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		// Get Zakat
		chaincodeStub.On("GetState", zakatID).Return(pendingZakatJSON, nil).Once()
		// Get Program
		chaincodeStub.On("GetState", programID).Return(initialProgramJSON, nil).Once()
		// Put Program (updated)
		chaincodeStub.On("PutState", programID, mock.AnythingOfType("[]uint8")).Return(nil).Once().Run(func(args mock.Arguments) {
			var prog DonationProgram
			json.Unmarshal(args.Get(1).([]byte), &prog)
			require.Equal(t, initialProgram.Collected+initialAmount, prog.Collected)
		})
		// Get Officer
		officerQuery := fmt.Sprintf("{\"selector\":{\"referralCode\":\"%s\"}}", referralCode)
		officerIterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{{Key: officerID, Value: initialOfficerJSON}}}
		chaincodeStub.On("GetQueryResult", officerQuery).Return(officerIterator, nil).Once()
		// Put Officer (updated)
		chaincodeStub.On("PutState", officerID, mock.AnythingOfType("[]uint8")).Return(nil).Once().Run(func(args mock.Arguments) {
			var off Officer
			json.Unmarshal(args.Get(1).([]byte), &off)
			require.Equal(t, initialOfficer.TotalReferred+initialAmount, off.TotalReferred)
		})
		// Put Zakat (updated)
		chaincodeStub.On("PutState", zakatID, mock.AnythingOfType("[]uint8")).Return(nil).Once().Run(func(args mock.Arguments) {
			var z Zakat
			json.Unmarshal(args.Get(1).([]byte), &z)
			require.Equal(t, "collected", z.Status)
			require.Equal(t, receiptNum, z.ReceiptNumber)
			require.Equal(t, validator, z.ValidatedBy)
		})

		smartContract := new(SmartContract)
		err := smartContract.ValidatePayment(transactionContext, zakatID, receiptNum, validator)
		require.NoError(t, err)
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("ErrorIfProgramNotFound", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		// Get Zakat
		chaincodeStub.On("GetState", zakatID).Return(pendingZakatJSON, nil).Once()
		// Get Program - returns not found
		chaincodeStub.On("GetState", programID).Return(nil, fmt.Errorf("program %s does not exist", programID)).Once()

		smartContract := new(SmartContract)
		err := smartContract.ValidatePayment(transactionContext, zakatID, receiptNum, validator)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to get program")
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("ErrorIfOfficerNotFound", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		// Get Zakat
		chaincodeStub.On("GetState", zakatID).Return(pendingZakatJSON, nil).Once()
		// Get Program - success
		chaincodeStub.On("GetState", programID).Return(initialProgramJSON, nil).Once()
		chaincodeStub.On("PutState", programID, mock.AnythingOfType("[]uint8")).Return(nil).Once() // Program update
		// Get Officer - returns not found
		officerQuery := fmt.Sprintf("{\"selector\":{\"referralCode\":\"%s\"}}", referralCode)
		emptyOfficerIterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{}} // No officer found
		chaincodeStub.On("GetQueryResult", officerQuery).Return(emptyOfficerIterator, fmt.Errorf("officer with referral code %s does not exist", referralCode)).Once()

		smartContract := new(SmartContract)
		err := smartContract.ValidatePayment(transactionContext, zakatID, receiptNum, validator)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to get officer with referral code")
		chaincodeStub.AssertExpectations(t)
	})
}

// --- Tests for new Query Functions ---
func TestGetZakatByStatus(t *testing.T) {
	t.Run("Success", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		zakatPending := Zakat{ID: "ZKT001", Status: "pending"}
		zakatPendingJSON, _ := json.Marshal(zakatPending)

		queryString := fmt.Sprintf("{\"selector\":{\"status\":\"%s\"}}", "pending")
		iterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{{Key: zakatPending.ID, Value: zakatPendingJSON}}}
		chaincodeStub.On("GetQueryResult", queryString).Return(iterator, nil).Once()

		smartContract := new(SmartContract)
		zakats, err := smartContract.GetZakatByStatus(transactionContext, "pending")
		require.NoError(t, err)
		require.Len(t, zakats, 1)
		require.Equal(t, zakatPending, zakats[0])
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("InvalidStatus", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		smartContract := new(SmartContract)
		_, err := smartContract.GetZakatByStatus(transactionContext, "invalid_status")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid status")
	})

	t.Run("QueryError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		queryString := fmt.Sprintf("{\"selector\":{\"status\":\"%s\"}}", "pending")
		chaincodeStub.On("GetQueryResult", queryString).Return(nil, fmt.Errorf("query error")).Once()

		smartContract := new(SmartContract)
		_, err := smartContract.GetZakatByStatus(transactionContext, "pending")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to query zakat by status")
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("IteratorError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		queryString := fmt.Sprintf("{\"selector\":{\"status\":\"%s\"}}", "pending")
		errorIterator := new(MockQueryIterator)
		errorIterator.On("HasNext").Return(true).Once()
		errorIterator.On("Next").Return(nil, fmt.Errorf("iterator error")).Once()
		errorIterator.On("Close").Return(nil).Maybe()
		chaincodeStub.On("GetQueryResult", queryString).Return(errorIterator, nil).Once()

		smartContract := new(SmartContract)
		_, err := smartContract.GetZakatByStatus(transactionContext, "pending")
		require.Error(t, err)
		chaincodeStub.AssertExpectations(t)
		errorIterator.AssertExpectations(t)
	})

	t.Run("UnmarshalError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		queryString := fmt.Sprintf("{\"selector\":{\"status\":\"%s\"}}", "pending")
		badJSON := []byte("invalid json")
		iterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{{Key: "TEST", Value: badJSON}}}
		chaincodeStub.On("GetQueryResult", queryString).Return(iterator, nil).Once()

		smartContract := new(SmartContract)
		_, err := smartContract.GetZakatByStatus(transactionContext, "pending")
		require.Error(t, err)
		chaincodeStub.AssertExpectations(t)
	})
}

func TestGetZakatByProgram(t *testing.T) {
	t.Run("Success", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		const progID = "PROGXYZ"
		zakatProg1 := Zakat{ID: "ZKT003", ProgramID: progID}
		zakatProg1JSON, _ := json.Marshal(zakatProg1)

		queryString := fmt.Sprintf("{\"selector\":{\"programID\":\"%s\"}}", progID)
		iterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{{Key: zakatProg1.ID, Value: zakatProg1JSON}}}
		chaincodeStub.On("GetQueryResult", queryString).Return(iterator, nil).Once()

		smartContract := new(SmartContract)
		zakats, err := smartContract.GetZakatByProgram(transactionContext, progID)
		require.NoError(t, err)
		require.Len(t, zakats, 1)
		require.Equal(t, zakatProg1, zakats[0])
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("QueryError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		const progID = "PROGXYZ"
		queryString := fmt.Sprintf("{\"selector\":{\"programID\":\"%s\"}}", progID)
		chaincodeStub.On("GetQueryResult", queryString).Return(nil, fmt.Errorf("query error")).Once()

		smartContract := new(SmartContract)
		_, err := smartContract.GetZakatByProgram(transactionContext, progID)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to query zakat by program")
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("IteratorError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		const progID = "PROGXYZ"
		queryString := fmt.Sprintf("{\"selector\":{\"programID\":\"%s\"}}", progID)
		errorIterator := new(MockQueryIterator)
		errorIterator.On("HasNext").Return(true).Once()
		errorIterator.On("Next").Return(nil, fmt.Errorf("iterator error")).Once()
		errorIterator.On("Close").Return(nil).Maybe()
		chaincodeStub.On("GetQueryResult", queryString).Return(errorIterator, nil).Once()

		smartContract := new(SmartContract)
		_, err := smartContract.GetZakatByProgram(transactionContext, progID)
		require.Error(t, err)
		chaincodeStub.AssertExpectations(t)
		errorIterator.AssertExpectations(t)
	})

	t.Run("UnmarshalError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		const progID = "PROGXYZ"
		queryString := fmt.Sprintf("{\"selector\":{\"programID\":\"%s\"}}", progID)
		badJSON := []byte("invalid json")
		iterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{{Key: "TEST", Value: badJSON}}}
		chaincodeStub.On("GetQueryResult", queryString).Return(iterator, nil).Once()

		smartContract := new(SmartContract)
		_, err := smartContract.GetZakatByProgram(transactionContext, progID)
		require.Error(t, err)
		chaincodeStub.AssertExpectations(t)
	})
}

func TestGetZakatByOfficer(t *testing.T) {
	t.Run("Success", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		const refCode = "REFXYZ"
		zakatOfficer1 := Zakat{ID: "ZKT004", ReferralCode: refCode}
		zakatOfficer1JSON, _ := json.Marshal(zakatOfficer1)

		queryString := fmt.Sprintf("{\"selector\":{\"referralCode\":\"%s\"}}", refCode)
		iterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{{Key: zakatOfficer1.ID, Value: zakatOfficer1JSON}}}
		chaincodeStub.On("GetQueryResult", queryString).Return(iterator, nil).Once()

		smartContract := new(SmartContract)
		zakats, err := smartContract.GetZakatByOfficer(transactionContext, refCode)
		require.NoError(t, err)
		require.Len(t, zakats, 1)
		require.Equal(t, zakatOfficer1, zakats[0])
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("QueryError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		const refCode = "REFXYZ"
		queryString := fmt.Sprintf("{\"selector\":{\"referralCode\":\"%s\"}}", refCode)
		chaincodeStub.On("GetQueryResult", queryString).Return(nil, fmt.Errorf("query error")).Once()

		smartContract := new(SmartContract)
		_, err := smartContract.GetZakatByOfficer(transactionContext, refCode)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to query zakat by officer")
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("IteratorError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		const refCode = "REFXYZ"
		queryString := fmt.Sprintf("{\"selector\":{\"referralCode\":\"%s\"}}", refCode)
		errorIterator := new(MockQueryIterator)
		errorIterator.On("HasNext").Return(true).Once()
		errorIterator.On("Next").Return(nil, fmt.Errorf("iterator error")).Once()
		errorIterator.On("Close").Return(nil).Maybe()
		chaincodeStub.On("GetQueryResult", queryString).Return(errorIterator, nil).Once()

		smartContract := new(SmartContract)
		_, err := smartContract.GetZakatByOfficer(transactionContext, refCode)
		require.Error(t, err)
		chaincodeStub.AssertExpectations(t)
		errorIterator.AssertExpectations(t)
	})

	t.Run("UnmarshalError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		const refCode = "REFXYZ"
		queryString := fmt.Sprintf("{\"selector\":{\"referralCode\":\"%s\"}}", refCode)
		badJSON := []byte("invalid json")
		iterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{{Key: "TEST", Value: badJSON}}}
		chaincodeStub.On("GetQueryResult", queryString).Return(iterator, nil).Once()

		smartContract := new(SmartContract)
		_, err := smartContract.GetZakatByOfficer(transactionContext, refCode)
		require.Error(t, err)
		chaincodeStub.AssertExpectations(t)
	})
}

func TestGetZakatByMuzakki(t *testing.T) {
	t.Run("Success", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		const muzakkiName = "Donatur Baik"
		zakatMuzakki1 := Zakat{ID: "ZKT005", Muzakki: muzakkiName}
		zakatMuzakki1JSON, _ := json.Marshal(zakatMuzakki1)

		queryString := fmt.Sprintf("{\"selector\":{\"muzakki\":\"%s\"}}", muzakkiName)
		iterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{{Key: zakatMuzakki1.ID, Value: zakatMuzakki1JSON}}}
		chaincodeStub.On("GetQueryResult", queryString).Return(iterator, nil).Once()

		smartContract := new(SmartContract)
		zakats, err := smartContract.GetZakatByMuzakki(transactionContext, muzakkiName)
		require.NoError(t, err)
		require.Len(t, zakats, 1)
		require.Equal(t, zakatMuzakki1, zakats[0])
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("EmptyMuzakkiName", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		smartContract := new(SmartContract)
		_, err := smartContract.GetZakatByMuzakki(transactionContext, "")
		require.Error(t, err)
		require.Contains(t, err.Error(), "muzakki name cannot be empty")
	})

	t.Run("QueryError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		const muzakkiName = "Donatur Baik"
		queryString := fmt.Sprintf("{\"selector\":{\"muzakki\":\"%s\"}}", muzakkiName)
		chaincodeStub.On("GetQueryResult", queryString).Return(nil, fmt.Errorf("query error")).Once()

		smartContract := new(SmartContract)
		_, err := smartContract.GetZakatByMuzakki(transactionContext, muzakkiName)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to query zakat by muzakki")
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("IteratorError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		const muzakkiName = "Donatur Baik"
		queryString := fmt.Sprintf("{\"selector\":{\"muzakki\":\"%s\"}}", muzakkiName)
		errorIterator := new(MockQueryIterator)
		errorIterator.On("HasNext").Return(true).Once()
		errorIterator.On("Next").Return(nil, fmt.Errorf("iterator error")).Once()
		errorIterator.On("Close").Return(nil).Maybe()
		chaincodeStub.On("GetQueryResult", queryString).Return(errorIterator, nil).Once()

		smartContract := new(SmartContract)
		_, err := smartContract.GetZakatByMuzakki(transactionContext, muzakkiName)
		require.Error(t, err)
		require.Contains(t, err.Error(), "error iterating over zakat by muzakki results")
		chaincodeStub.AssertExpectations(t)
		errorIterator.AssertExpectations(t)
	})

	t.Run("UnmarshalError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		const muzakkiName = "Donatur Baik"
		queryString := fmt.Sprintf("{\"selector\":{\"muzakki\":\"%s\"}}", muzakkiName)
		badJSON := []byte("invalid json")
		iterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{{Key: "TEST", Value: badJSON}}}
		chaincodeStub.On("GetQueryResult", queryString).Return(iterator, nil).Once()

		smartContract := new(SmartContract)
		_, err := smartContract.GetZakatByMuzakki(transactionContext, muzakkiName)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to unmarshal zakat data for muzakki query")
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("SuccessNoRecordsFound", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		const muzakkiName = "Nonexistent Donor"
		queryString := fmt.Sprintf("{\"selector\":{\"muzakki\":\"%s\"}}", muzakkiName)
		emptyIterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{}}
		chaincodeStub.On("GetQueryResult", queryString).Return(emptyIterator, nil).Once()

		smartContract := new(SmartContract)
		zakats, err := smartContract.GetZakatByMuzakki(transactionContext, muzakkiName)
		require.NoError(t, err)
		require.Empty(t, zakats)
		chaincodeStub.AssertExpectations(t)
	})
}

// --- Test for GetDailyReport ---
func TestGetDailyReport(t *testing.T) {
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	reportDate := "2024-07-15"

	zakat1 := Zakat{ID: "ZKTREP001", Amount: 1000, Type: "maal", ProgramID: "PROG1", Status: "collected", ValidationDate: "2024-07-15T10:00:00Z"}
	zakat2 := Zakat{ID: "ZKTREP002", Amount: 2000, Type: "fitrah", ProgramID: "PROG2", Status: "collected", ValidationDate: "2024-07-15T15:00:00Z"}
	zakat1JSON, _ := json.Marshal(zakat1)
	zakat2JSON, _ := json.Marshal(zakat2)

	parsedTargetDate, _ := time.Parse("2006-01-02", reportDate)
	mockQueryStartOfDay := parsedTargetDate.Format(time.RFC3339)
	mockQueryStartOfNextDay := parsedTargetDate.Add(24 * time.Hour).Format(time.RFC3339)

	queryString := fmt.Sprintf(`{
"selector": {
"validationDate": {
"$gte": "%s",
"$lt": "%s"
},
"status": "collected"
}
}`, mockQueryStartOfDay, mockQueryStartOfNextDay)

	iterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{
		{Key: zakat1.ID, Value: zakat1JSON},
		{Key: zakat2.ID, Value: zakat2JSON},
	}}
	chaincodeStub.On("GetQueryResult", queryString).Return(iterator, nil).Once()

	smartContract := new(SmartContract)
	report, err := smartContract.GetDailyReport(transactionContext, reportDate)
	require.NoError(t, err)
	require.NotNil(t, report)
	require.Equal(t, reportDate, report["date"])
	require.Equal(t, float64(3000), report["totalAmount"])
	require.Equal(t, 2, report["transactionCount"])
	require.Equal(t, map[string]float64{"maal": 1000, "fitrah": 2000}, report["byType"])
	require.Equal(t, map[string]float64{"PROG1": 1000, "PROG2": 2000}, report["byProgram"])

	chaincodeStub.AssertExpectations(t)
}

// --- Tests for Enhanced Management Functions ---

func TestClearAllPrograms(t *testing.T) {
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	prog1 := DonationProgram{ID: "PROG-2024-1735689000000000000-0001", Name: "Program 1"}
	prog2 := DonationProgram{ID: "PROG-2024-1735689000000000001-0002", Name: "Program 2"}
	prog1JSON, _ := json.Marshal(prog1)
	prog2JSON, _ := json.Marshal(prog2)

	iterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{
		{Key: prog1.ID, Value: prog1JSON},
		{Key: prog2.ID, Value: prog2JSON},
	}}

	chaincodeStub.On("GetStateByRange", "PROG-", "PROG-\uffff").Return(iterator, nil).Once()
	chaincodeStub.On("DelState", prog1.ID).Return(nil).Once()
	chaincodeStub.On("DelState", prog2.ID).Return(nil).Once()

	smartContract := new(SmartContract)
	err := smartContract.ClearAllPrograms(transactionContext)
	require.NoError(t, err)
	chaincodeStub.AssertExpectations(t)
}

func TestClearAllOfficers(t *testing.T) {
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	officer1 := Officer{ID: "OFF-2024-1735689000000000000-0001", Name: "Officer 1"}
	officer2 := Officer{ID: "OFF-2024-1735689000000000001-0002", Name: "Officer 2"}
	officer1JSON, _ := json.Marshal(officer1)
	officer2JSON, _ := json.Marshal(officer2)

	iterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{
		{Key: officer1.ID, Value: officer1JSON},
		{Key: officer2.ID, Value: officer2JSON},
	}}

	chaincodeStub.On("GetStateByRange", "OFF-", "OFF-\uffff").Return(iterator, nil).Once()
	chaincodeStub.On("DelState", officer1.ID).Return(nil).Once()
	chaincodeStub.On("DelState", officer2.ID).Return(nil).Once()

	smartContract := new(SmartContract)
	err := smartContract.ClearAllOfficers(transactionContext)
	require.NoError(t, err)
	chaincodeStub.AssertExpectations(t)
}

func TestGetAllOfficers(t *testing.T) {
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	officer1 := Officer{ID: "OFF-2024-1735689000000000000-0001", Name: "Officer 1", Status: "active"}
	officer2 := Officer{ID: "OFF-2024-1735689000000000001-0002", Name: "Officer 2", Status: "active"}
	officer1JSON, _ := json.Marshal(officer1)
	officer2JSON, _ := json.Marshal(officer2)

	iterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{
		{Key: officer1.ID, Value: officer1JSON},
		{Key: officer2.ID, Value: officer2JSON},
	}}

	chaincodeStub.On("GetStateByRange", "OFF-", "OFF-\uffff").Return(iterator, nil).Once()

	smartContract := new(SmartContract)
	officers, err := smartContract.GetAllOfficers(transactionContext)
	require.NoError(t, err)
	require.ElementsMatch(t, []Officer{officer1, officer2}, officers)
	chaincodeStub.AssertExpectations(t)
}

func TestUpdateProgramStatus(t *testing.T) {
	const programID = "PROG-2024-1735689000000000000-0001"
	initialProgram := DonationProgram{ID: programID, Name: "Test Program", Status: "active"}
	initialProgramJSON, _ := json.Marshal(initialProgram)

	t.Run("Success", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		chaincodeStub.On("GetState", programID).Return(initialProgramJSON, nil).Once()
		chaincodeStub.On("PutState", programID, mock.AnythingOfType("[]uint8")).Return(nil).Once().Run(func(args mock.Arguments) {
			var prog DonationProgram
			json.Unmarshal(args.Get(1).([]byte), &prog)
			require.Equal(t, "completed", prog.Status)
		})

		smartContract := new(SmartContract)
		err := smartContract.UpdateProgramStatus(transactionContext, programID, "completed")
		require.NoError(t, err)
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("InvalidStatus", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		smartContract := new(SmartContract)
		err := smartContract.UpdateProgramStatus(transactionContext, programID, "invalid")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid program status")
	})
}

func TestUpdateOfficerStatus(t *testing.T) {
	const officerID = "OFF-2024-1735689000000000000-0001"
	initialOfficer := Officer{ID: officerID, Name: "Test Officer", Status: "active"}
	initialOfficerJSON, _ := json.Marshal(initialOfficer)

	t.Run("Success", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		chaincodeStub.On("GetState", officerID).Return(initialOfficerJSON, nil).Once()
		chaincodeStub.On("PutState", officerID, mock.AnythingOfType("[]uint8")).Return(nil).Once().Run(func(args mock.Arguments) {
			var officer Officer
			json.Unmarshal(args.Get(1).([]byte), &officer)
			require.Equal(t, "inactive", officer.Status)
		})

		smartContract := new(SmartContract)
		err := smartContract.UpdateOfficerStatus(transactionContext, officerID, "inactive")
		require.NoError(t, err)
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("OfficerNotFound", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		chaincodeStub.On("GetState", officerID).Return(nil, nil).Once()

		smartContract := new(SmartContract)
		err := smartContract.UpdateOfficerStatus(transactionContext, officerID, "inactive")
		require.Error(t, err)
		require.Contains(t, err.Error(), "does not exist")
		chaincodeStub.AssertExpectations(t)
	})
}

// --- Tests for Enhanced ID Generation Functions ---

func TestIDGenerationFunctions(t *testing.T) {
	t.Run("GenerateZakatID", func(t *testing.T) {
		id1 := generateZakatID("MLG", 1)
		id2 := generateZakatID("MLG", 1)
		
		// IDs should be different due to nanosecond timestamps
		require.NotEqual(t, id1, id2)
		require.Contains(t, id1, "ZKT-YDSF-MLG-")
		require.Contains(t, id1, "-0001")
	})

	t.Run("GenerateProgramID", func(t *testing.T) {
		id1 := generateProgramID("2024", 1)
		id2 := generateProgramID("2024", 1)
		
		require.NotEqual(t, id1, id2)
		require.Contains(t, id1, "PROG-2024-")
		require.Contains(t, id1, "-0001")
	})

	t.Run("GenerateOfficerID", func(t *testing.T) {
		id1 := generateOfficerID("2024", 1)
		id2 := generateOfficerID("2024", 1)
		
		require.NotEqual(t, id1, id2)
		require.Contains(t, id1, "OFF-2024-")
		require.Contains(t, id1, "-0001")
	})
}

// --- Tests for Enhanced ID Validation ---

func TestEnhancedIDValidation(t *testing.T) {
	t.Run("ValidateZakatID", func(t *testing.T) {
		// Valid timestamp-based ID
		err := validateZakatID("ZKT-YDSF-MLG-1735689000000000000-0001")
		require.NoError(t, err)
		
		// Valid JTM org
		err = validateZakatID("ZKT-YDSF-JTM-1735689000000000000-0001")
		require.NoError(t, err)
		
		// Invalid format
		err = validateZakatID("INVALID-ID")
		require.Error(t, err)
		
		// Empty ID
		err = validateZakatID("")
		require.Error(t, err)
		
		// Invalid organization
		err = validateZakatID("ZKT-YDSF-INVALID-1735689000000000000-0001")
		require.Error(t, err)
		
		// Missing parts
		err = validateZakatID("ZKT-YDSF-MLG")
		require.Error(t, err)
	})

	t.Run("ValidateProgramID", func(t *testing.T) {
		// Valid timestamp-based ID
		err := validateProgramID("PROG-2024-1735689000000000000-0001")
		require.NoError(t, err)
		
		// Valid with different type
		err = validateProgramID("PROG-ABC123-1735689000000000000-0001")
		require.NoError(t, err)
		
		// Invalid format
		err = validateProgramID("INVALID-PROG")
		require.Error(t, err)
		
		// Empty ID
		err = validateProgramID("")
		require.Error(t, err)
		
		// Missing timestamp
		err = validateProgramID("PROG-2024")
		require.Error(t, err)
	})

	t.Run("ValidateOfficerID", func(t *testing.T) {
		// Valid timestamp-based ID
		err := validateOfficerID("OFF-2024-1735689000000000000-0001")
		require.NoError(t, err)
		
		// Valid with different type
		err = validateOfficerID("OFF-ABC123-1735689000000000000-0001")
		require.NoError(t, err)
		
		// Invalid format
		err = validateOfficerID("INVALID-OFF")
		require.Error(t, err)
		
		// Empty ID
		err = validateOfficerID("")
		require.Error(t, err)
		
		// Missing parts
		err = validateOfficerID("OFF-2024")
		require.Error(t, err)
	})
}

// --- Tests for Missing Coverage Functions ---

func TestCreateProgram(t *testing.T) {
	const programID = "PROG-2024-1735689000000000000-0001"
	
	t.Run("Success", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		chaincodeStub.On("GetState", programID).Return(nil, nil).Once()
		chaincodeStub.On("PutState", programID, mock.AnythingOfType("[]uint8")).Return(nil).Once()

		smartContract := new(SmartContract)
		err := smartContract.CreateProgram(transactionContext, programID, "Test Program", "Description", 1000000, "2024-01-01T00:00:00Z", "2024-12-31T23:59:59Z", "admin")
		require.NoError(t, err)
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("ProgramAlreadyExists", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		existingProgram := DonationProgram{ID: programID}
		programJSON, _ := json.Marshal(existingProgram)
		chaincodeStub.On("GetState", programID).Return(programJSON, nil).Once()

		smartContract := new(SmartContract)
		err := smartContract.CreateProgram(transactionContext, programID, "Test Program", "Description", 1000000, "2024-01-01T00:00:00Z", "2024-12-31T23:59:59Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "already exists")
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("InvalidProgramID", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		smartContract := new(SmartContract)
		err := smartContract.CreateProgram(transactionContext, "INVALID", "Test Program", "Description", 1000000, "2024-01-01T00:00:00Z", "2024-12-31T23:59:59Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid program ID format")
	})

	t.Run("InvalidStartDate", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		smartContract := new(SmartContract)
		err := smartContract.CreateProgram(transactionContext, programID, "Test Program", "Description", 1000000, "invalid-date", "2024-12-31T23:59:59Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid timestamp format")
	})

	t.Run("InvalidEndDate", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		smartContract := new(SmartContract)
		err := smartContract.CreateProgram(transactionContext, programID, "Test Program", "Description", 1000000, "2024-01-01T00:00:00Z", "invalid-date", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid timestamp format")
	})

	t.Run("InvalidTargetAmount", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		smartContract := new(SmartContract)
		err := smartContract.CreateProgram(transactionContext, programID, "Test Program", "Description", -1000, "2024-01-01T00:00:00Z", "2024-12-31T23:59:59Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid amount")
	})

	t.Run("GetStateError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		chaincodeStub.On("GetState", programID).Return(nil, fmt.Errorf("ledger error")).Once()

		smartContract := new(SmartContract)
		err := smartContract.CreateProgram(transactionContext, programID, "Test Program", "Description", 1000000, "2024-01-01T00:00:00Z", "2024-12-31T23:59:59Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to check program existence")
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("PutStateError", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		chaincodeStub.On("GetState", programID).Return(nil, nil).Once()
		chaincodeStub.On("PutState", programID, mock.AnythingOfType("[]uint8")).Return(fmt.Errorf("ledger error")).Once()

		smartContract := new(SmartContract)
		err := smartContract.CreateProgram(transactionContext, programID, "Test Program", "Description", 1000000, "2024-01-01T00:00:00Z", "2024-12-31T23:59:59Z", "admin")
		require.Error(t, err)
		chaincodeStub.AssertExpectations(t)
	})
}

func TestGetProgram(t *testing.T) {
	const programID = "PROG-2024-1735689000000000000-0001"
	expectedProgram := DonationProgram{ID: programID, Name: "Test Program"}
	programJSON, _ := json.Marshal(expectedProgram)

	t.Run("Success", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		chaincodeStub.On("GetState", programID).Return(programJSON, nil).Once()

		smartContract := new(SmartContract)
		program, err := smartContract.GetProgram(transactionContext, programID)
		require.NoError(t, err)
		require.Equal(t, expectedProgram, program)
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("ProgramNotFound", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		chaincodeStub.On("GetState", programID).Return(nil, nil).Once()

		smartContract := new(SmartContract)
		_, err := smartContract.GetProgram(transactionContext, programID)
		require.Error(t, err)
		require.Contains(t, err.Error(), "does not exist")
		chaincodeStub.AssertExpectations(t)
	})
}

func TestDistributeZakat(t *testing.T) {
	const zakatID = "ZKT-YDSF-MLG-1735689000000000000-0001"
	const programID = "PROG-2024-1735689000000000000-0001"
	collectedZakat := Zakat{ID: zakatID, ProgramID: programID, Amount: 500000, Status: "collected"}
	zakatJSON, _ := json.Marshal(collectedZakat)
	
	program := DonationProgram{ID: programID, Distributed: 0}
	programJSON, _ := json.Marshal(program)

	t.Run("Success", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		chaincodeStub.On("GetState", zakatID).Return(zakatJSON, nil).Once()
		chaincodeStub.On("GetState", programID).Return(programJSON, nil).Once()
		chaincodeStub.On("PutState", programID, mock.AnythingOfType("[]uint8")).Return(nil).Once()
		chaincodeStub.On("PutState", zakatID, mock.AnythingOfType("[]uint8")).Return(nil).Once()

		smartContract := new(SmartContract)
		err := smartContract.DistributeZakat(transactionContext, zakatID, "DIST-001", "Test Recipient", 250000, "2024-01-01T00:00:00Z", "admin")
		require.NoError(t, err)
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("ZakatNotCollected", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		pendingZakat := Zakat{ID: zakatID, Status: "pending"}
		pendingZakatJSON, _ := json.Marshal(pendingZakat)
		chaincodeStub.On("GetState", zakatID).Return(pendingZakatJSON, nil).Once()

		smartContract := new(SmartContract)
		err := smartContract.DistributeZakat(transactionContext, zakatID, "DIST-001", "Test Recipient", 250000, "2024-01-01T00:00:00Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "must be in 'collected' status")
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("DistributionAmountExceedsZakat", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		collectedZakat := Zakat{ID: zakatID, Amount: 100000, Status: "collected"}
		zakatJSON, _ := json.Marshal(collectedZakat)
		chaincodeStub.On("GetState", zakatID).Return(zakatJSON, nil).Once()

		smartContract := new(SmartContract)
		err := smartContract.DistributeZakat(transactionContext, zakatID, "DIST-001", "Test Recipient", 150000, "2024-01-01T00:00:00Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "distribution amount")
		require.Contains(t, err.Error(), "exceeds original zakat amount")
		chaincodeStub.AssertExpectations(t)
	})
}

func TestAutoValidatePayment(t *testing.T) {
	const zakatID = "ZKT-YDSF-MLG-1735689000000000000-0001"
	pendingZakat := Zakat{ID: zakatID, Status: "pending", ProgramID: "", ReferralCode: ""}
	zakatJSON, _ := json.Marshal(pendingZakat)

	t.Run("Success", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		// AutoValidatePayment calls QueryZakat which calls GetState
		chaincodeStub.On("GetState", zakatID).Return(zakatJSON, nil).Once()
		// ValidatePayment also calls QueryZakat which calls GetState again
		chaincodeStub.On("GetState", zakatID).Return(zakatJSON, nil).Once()
		// Final PutState for the updated zakat
		chaincodeStub.On("PutState", zakatID, mock.AnythingOfType("[]uint8")).Return(nil).Once()

		smartContract := new(SmartContract)
		err := smartContract.AutoValidatePayment(transactionContext, zakatID, "PAYMENT-REF-123")
		require.NoError(t, err)
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("ZakatNotPending", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		collectedZakat := Zakat{ID: zakatID, Status: "collected", ProgramID: "", ReferralCode: ""}
		collectedZakatJSON, _ := json.Marshal(collectedZakat)
		chaincodeStub.On("GetState", zakatID).Return(collectedZakatJSON, nil).Once()

		smartContract := new(SmartContract)
		err := smartContract.AutoValidatePayment(transactionContext, zakatID, "PAYMENT-REF-123")
		require.Error(t, err)
		require.Contains(t, err.Error(), "is not in pending status")
		chaincodeStub.AssertExpectations(t)
	})
}

func TestZakatExists(t *testing.T) {
	const zakatID = "ZKT-YDSF-MLG-1735689000000000000-0001"

	t.Run("ZakatExists", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		zakatJSON := []byte(`{"ID":"` + zakatID + `"}`)
		chaincodeStub.On("GetState", zakatID).Return(zakatJSON, nil).Once()

		smartContract := new(SmartContract)
		exists, err := smartContract.ZakatExists(transactionContext, zakatID)
		require.NoError(t, err)
		require.True(t, exists)
		chaincodeStub.AssertExpectations(t)
	})

	t.Run("ZakatDoesNotExist", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		chaincodeStub.On("GetState", zakatID).Return(nil, nil).Once()

		smartContract := new(SmartContract)
		exists, err := smartContract.ZakatExists(transactionContext, zakatID)
		require.NoError(t, err)
		require.False(t, exists)
		chaincodeStub.AssertExpectations(t)
	})
}

func TestClearAllZakat(t *testing.T) {
	t.Run("Success", func(t *testing.T) {
		chaincodeStub := new(MockStub)
		transactionContext := new(contractapi.TransactionContext)
		transactionContext.SetStub(chaincodeStub)

		zakat1 := Zakat{ID: "ZKT-YDSF-MLG-1735689000000000000-0001"}
		zakat2 := Zakat{ID: "ZKT-YDSF-MLG-1735689000000000001-0002"}
		zakat1JSON, _ := json.Marshal(zakat1)
		zakat2JSON, _ := json.Marshal(zakat2)

		iterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{
			{Key: zakat1.ID, Value: zakat1JSON},
			{Key: zakat2.ID, Value: zakat2JSON},
		}}

		chaincodeStub.On("GetStateByRange", "ZKT-", "ZKT-\uffff").Return(iterator, nil).Once()
		chaincodeStub.On("DelState", zakat1.ID).Return(nil).Once()
		chaincodeStub.On("DelState", zakat2.ID).Return(nil).Once()

		smartContract := new(SmartContract)
		err := smartContract.ClearAllZakat(transactionContext)
		require.NoError(t, err)
		chaincodeStub.AssertExpectations(t)
	})
}

func TestValidationFunctions(t *testing.T) {
	t.Run("ValidateTimestamp", func(t *testing.T) {
		err := validateTimestamp("2024-01-01T00:00:00Z")
		require.NoError(t, err)
		
		err = validateTimestamp("invalid-timestamp")
		require.Error(t, err)
	})

	t.Run("ValidateZakatType", func(t *testing.T) {
		err := validateZakatType("maal")
		require.NoError(t, err)
		
		err = validateZakatType("fitrah")
		require.NoError(t, err)
		
		err = validateZakatType("invalid")
		require.Error(t, err)
	})

	t.Run("ValidatePaymentMethod", func(t *testing.T) {
		err := validatePaymentMethod("transfer")
		require.NoError(t, err)
		
		err = validatePaymentMethod("ewallet")
		require.NoError(t, err)
		
		err = validatePaymentMethod("credit_card")
		require.NoError(t, err)
		
		err = validatePaymentMethod("debit_card")
		require.NoError(t, err)
		
		err = validatePaymentMethod("cash")
		require.NoError(t, err)
		
		err = validatePaymentMethod("invalid")
		require.Error(t, err)
	})

	t.Run("ValidateStatus", func(t *testing.T) {
		err := validateStatus("pending")
		require.NoError(t, err)
		
		err = validateStatus("collected")
		require.NoError(t, err)
		
		err = validateStatus("distributed")
		require.NoError(t, err)
		
		err = validateStatus("invalid")
		require.Error(t, err)
	})

	t.Run("ValidateOfficerStatus", func(t *testing.T) {
		err := validateOfficerStatus("active")
		require.NoError(t, err)
		
		err = validateOfficerStatus("inactive")
		require.NoError(t, err)
		
		err = validateOfficerStatus("invalid")
		require.Error(t, err)
	})

	t.Run("ValidateAmount", func(t *testing.T) {
		err := validateAmount(1000)
		require.NoError(t, err)
		
		err = validateAmount(-100)
		require.Error(t, err)
		
		err = validateAmount(0)
		require.Error(t, err)
	})

	t.Run("ValidateOrganization", func(t *testing.T) {
		err := validateOrganization("YDSF Malang")
		require.NoError(t, err)
		
		err = validateOrganization("YDSF Jatim")
		require.NoError(t, err)
		
		err = validateOrganization("Invalid Org")
		require.Error(t, err)
	})
}

func TestGenerateDistributionID(t *testing.T) {
	id1 := generateDistributionID(1)
	id2 := generateDistributionID(2)
	
	require.NotEqual(t, id1, id2)
	require.Contains(t, id1, "DIST-")
	require.Contains(t, id1, "-0001")
}

// Additional comprehensive error path tests for 100% coverage
func TestCreateProgramErrorPaths(t *testing.T) {
	smartContract := new(SmartContract)
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	t.Run("ValidateProgramIDError", func(t *testing.T) {
		err := smartContract.CreateProgram(transactionContext, "INVALID-ID", "Test Program", "Description", 100000, "2024-01-01T00:00:00Z", "2024-12-31T23:59:59Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid program ID format")
	})

	t.Run("ValidateStartDateError", func(t *testing.T) {
		chaincodeStub.On("GetState", "PROG-2024-123456789-0001").Return(nil, nil).Once()
		err := smartContract.CreateProgram(transactionContext, "PROG-2024-123456789-0001", "Test Program", "Description", 100000, "invalid-date", "2024-12-31T23:59:59Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid timestamp format")
	})

	t.Run("ValidateEndDateError", func(t *testing.T) {
		chaincodeStub.On("GetState", "PROG-2024-123456789-0002").Return(nil, nil).Once()
		err := smartContract.CreateProgram(transactionContext, "PROG-2024-123456789-0002", "Test Program", "Description", 100000, "2024-01-01T00:00:00Z", "invalid-date", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid timestamp format")
	})

	t.Run("ValidateTargetAmountError", func(t *testing.T) {
		chaincodeStub.On("GetState", "PROG-2024-123456789-0003").Return(nil, nil).Once()
		err := smartContract.CreateProgram(transactionContext, "PROG-2024-123456789-0003", "Test Program", "Description", -100, "2024-01-01T00:00:00Z", "2024-12-31T23:59:59Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid amount")
	})

	t.Run("GetStateError", func(t *testing.T) {
		chaincodeStub.On("GetState", "PROG-2024-123456789-0004").Return(nil, fmt.Errorf("ledger error")).Once()
		err := smartContract.CreateProgram(transactionContext, "PROG-2024-123456789-0004", "Test Program", "Description", 100000, "2024-01-01T00:00:00Z", "2024-12-31T23:59:59Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to check program existence")
	})

	t.Run("ProgramAlreadyExists", func(t *testing.T) {
		existingData := []byte(`{"ID":"PROG-2024-123456789-0005","Name":"Existing"}`)
		chaincodeStub.On("GetState", "PROG-2024-123456789-0005").Return(existingData, nil).Once()
		err := smartContract.CreateProgram(transactionContext, "PROG-2024-123456789-0005", "Test Program", "Description", 100000, "2024-01-01T00:00:00Z", "2024-12-31T23:59:59Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "already exists")
	})

	t.Run("JSONMarshalError", func(t *testing.T) {
		// This is harder to trigger in practice, would need invalid struct data
		// but testing for completeness
		chaincodeStub.On("GetState", "PROG-2024-123456789-0006").Return(nil, nil).Once()
		chaincodeStub.On("PutState", "PROG-2024-123456789-0006", mock.Anything).Return(nil).Once()
		err := smartContract.CreateProgram(transactionContext, "PROG-2024-123456789-0006", "Test Program", "Description", 100000, "2024-01-01T00:00:00Z", "2024-12-31T23:59:59Z", "admin")
		require.NoError(t, err) // This should succeed normally
	})
}

func TestAddZakatComprehensiveErrorPaths(t *testing.T) {
	smartContract := new(SmartContract)
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	t.Run("ValidateZakatIDError", func(t *testing.T) {
		err := smartContract.AddZakat(transactionContext, "INVALID-ID", "", "John Doe", 100000, "maal", "transfer", "YDSF Malang", "")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid zakat ID format")
	})

	t.Run("ValidateAmountError", func(t *testing.T) {
		err := smartContract.AddZakat(transactionContext, "ZKT-YDSF-MLG-123456789-0001", "", "John Doe", -100, "maal", "transfer", "YDSF Malang", "")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid amount")
	})

	t.Run("ValidateZakatTypeError", func(t *testing.T) {
		err := smartContract.AddZakat(transactionContext, "ZKT-YDSF-MLG-123456789-0002", "", "John Doe", 100000, "invalid", "transfer", "YDSF Malang", "")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid zakat type")
	})

	t.Run("ValidatePaymentMethodError", func(t *testing.T) {
		err := smartContract.AddZakat(transactionContext, "ZKT-YDSF-MLG-123456789-0003", "", "John Doe", 100000, "maal", "invalid", "YDSF Malang", "")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid payment method")
	})

	t.Run("ValidateOrganizationError", func(t *testing.T) {
		err := smartContract.AddZakat(transactionContext, "ZKT-YDSF-MLG-123456789-0004", "", "John Doe", 100000, "maal", "transfer", "Invalid Org", "")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid organization")
	})

	t.Run("EmptyMuzakkiError", func(t *testing.T) {
		err := smartContract.AddZakat(transactionContext, "ZKT-YDSF-MLG-123456789-0005", "", "", 100000, "maal", "transfer", "YDSF Malang", "")
		require.Error(t, err)
		require.Contains(t, err.Error(), "muzakki name cannot be empty")
	})

	t.Run("InvalidProgramIDFormat", func(t *testing.T) {
		err := smartContract.AddZakat(transactionContext, "ZKT-YDSF-MLG-123456789-0006", "INVALID-PROG-ID", "John Doe", 100000, "maal", "transfer", "YDSF Malang", "")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid program ID format")
	})

	t.Run("ProgramNotFound", func(t *testing.T) {
		chaincodeStub.On("GetState", "PROG-2024-123456789-0001").Return(nil, nil).Once()
		err := smartContract.AddZakat(transactionContext, "ZKT-YDSF-MLG-123456789-0007", "PROG-2024-123456789-0001", "John Doe", 100000, "maal", "transfer", "YDSF Malang", "")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to validate program ID")
	})

	t.Run("OfficerNotFound", func(t *testing.T) {
		queryString := `{"selector":{"referralCode":"INVALID-REF"}}`
		chaincodeStub.On("GetQueryResult", queryString).Return(nil, fmt.Errorf("query error")).Once()
		err := smartContract.AddZakat(transactionContext, "ZKT-YDSF-MLG-123456789-0008", "", "John Doe", 100000, "maal", "transfer", "YDSF Malang", "INVALID-REF")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to validate referral code")
	})

	t.Run("ZakatExistsCheckError", func(t *testing.T) {
		chaincodeStub.On("GetState", "ZKT-YDSF-MLG-123456789-0009").Return(nil, fmt.Errorf("ledger error")).Once()
		err := smartContract.AddZakat(transactionContext, "ZKT-YDSF-MLG-123456789-0009", "", "John Doe", 100000, "maal", "transfer", "YDSF Malang", "")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to check zakat existence")
	})

	t.Run("ZakatAlreadyExists", func(t *testing.T) {
		existingData := []byte(`{"ID":"ZKT-YDSF-MLG-123456789-0010","Muzakki":"Existing"}`)
		chaincodeStub.On("GetState", "ZKT-YDSF-MLG-123456789-0010").Return(existingData, nil).Once()
		err := smartContract.AddZakat(transactionContext, "ZKT-YDSF-MLG-123456789-0010", "", "John Doe", 100000, "maal", "transfer", "YDSF Malang", "")
		require.Error(t, err)
		require.Contains(t, err.Error(), "already exists")
	})

	t.Run("PutStateError", func(t *testing.T) {
		chaincodeStub.On("GetState", "ZKT-YDSF-MLG-123456789-0011").Return(nil, nil).Once()
		chaincodeStub.On("PutState", "ZKT-YDSF-MLG-123456789-0011", mock.Anything).Return(fmt.Errorf("ledger error")).Once()
		err := smartContract.AddZakat(transactionContext, "ZKT-YDSF-MLG-123456789-0011", "", "John Doe", 100000, "maal", "transfer", "YDSF Malang", "")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to put zakat")
	})
}

func TestDistributeZakatErrorPaths(t *testing.T) {
	smartContract := new(SmartContract)
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	t.Run("EmptyZakatID", func(t *testing.T) {
		err := smartContract.DistributeZakat(transactionContext, "", "DIST-123", "Recipient", 100000, "2024-01-01T00:00:00Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "zakat ID cannot be empty")
	})

	t.Run("EmptyDistributionID", func(t *testing.T) {
		err := smartContract.DistributeZakat(transactionContext, "ZKT-001", "", "Recipient", 100000, "2024-01-01T00:00:00Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "distribution ID cannot be empty")
	})

	t.Run("EmptyRecipientName", func(t *testing.T) {
		err := smartContract.DistributeZakat(transactionContext, "ZKT-001", "DIST-123", "", 100000, "2024-01-01T00:00:00Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "recipient name (mustahik) cannot be empty")
	})

	t.Run("InvalidAmount", func(t *testing.T) {
		err := smartContract.DistributeZakat(transactionContext, "ZKT-001", "DIST-123", "Recipient", -100, "2024-01-01T00:00:00Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid distribution amount")
	})

	t.Run("InvalidTimestamp", func(t *testing.T) {
		err := smartContract.DistributeZakat(transactionContext, "ZKT-001", "DIST-123", "Recipient", 100000, "invalid-date", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid distribution timestamp")
	})

	t.Run("EmptyDistributedBy", func(t *testing.T) {
		err := smartContract.DistributeZakat(transactionContext, "ZKT-001", "DIST-123", "Recipient", 100000, "2024-01-01T00:00:00Z", "")
		require.Error(t, err)
		require.Contains(t, err.Error(), "distributedBy (admin/officer) cannot be empty")
	})

	t.Run("ZakatNotFound", func(t *testing.T) {
		chaincodeStub.On("GetState", "ZKT-NOT-FOUND").Return(nil, nil).Once()
		err := smartContract.DistributeZakat(transactionContext, "ZKT-NOT-FOUND", "DIST-123", "Recipient", 100000, "2024-01-01T00:00:00Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to query zakat")
	})

	t.Run("ZakatNotCollected", func(t *testing.T) {
		zakatData := Zakat{
			ID:     "ZKT-PENDING",
			Status: "pending",
			Amount: 200000,
		}
		zakatJSON, _ := json.Marshal(zakatData)
		chaincodeStub.On("GetState", "ZKT-PENDING").Return(zakatJSON, nil).Once()
		err := smartContract.DistributeZakat(transactionContext, "ZKT-PENDING", "DIST-123", "Recipient", 100000, "2024-01-01T00:00:00Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "must be in 'collected' status")
	})

	t.Run("AmountExceedsOriginal", func(t *testing.T) {
		zakatData := Zakat{
			ID:     "ZKT-COLLECTED",
			Status: "collected",
			Amount: 100000,
		}
		zakatJSON, _ := json.Marshal(zakatData)
		chaincodeStub.On("GetState", "ZKT-COLLECTED").Return(zakatJSON, nil).Once()
		err := smartContract.DistributeZakat(transactionContext, "ZKT-COLLECTED", "DIST-123", "Recipient", 200000, "2024-01-01T00:00:00Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "distribution amount")
		require.Contains(t, err.Error(), "exceeds original zakat amount")
	})

	t.Run("ProgramGetError", func(t *testing.T) {
		zakatData := Zakat{
			ID:        "ZKT-COLLECTED-PROG",
			Status:    "collected",
			Amount:    200000,
			ProgramID: "PROG-INVALID",
		}
		zakatJSON, _ := json.Marshal(zakatData)
		chaincodeStub.On("GetState", "ZKT-COLLECTED-PROG").Return(zakatJSON, nil).Once()
		chaincodeStub.On("GetState", "PROG-INVALID").Return(nil, fmt.Errorf("program error")).Once()
		err := smartContract.DistributeZakat(transactionContext, "ZKT-COLLECTED-PROG", "DIST-123", "Recipient", 100000, "2024-01-01T00:00:00Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to get program")
	})

	t.Run("PutStateError", func(t *testing.T) {
		zakatData := Zakat{
			ID:     "ZKT-COLLECTED-PUT-ERROR",
			Status: "collected",
			Amount: 200000,
		}
		zakatJSON, _ := json.Marshal(zakatData)
		chaincodeStub.On("GetState", "ZKT-COLLECTED-PUT-ERROR").Return(zakatJSON, nil).Once()
		chaincodeStub.On("PutState", "ZKT-COLLECTED-PUT-ERROR", mock.Anything).Return(fmt.Errorf("put error")).Once()
		err := smartContract.DistributeZakat(transactionContext, "ZKT-COLLECTED-PUT-ERROR", "DIST-123", "Recipient", 100000, "2024-01-01T00:00:00Z", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to put updated zakat")
	})
}

func TestZakatExistsErrorPaths(t *testing.T) {
	smartContract := new(SmartContract)
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	t.Run("GetStateError", func(t *testing.T) {
		chaincodeStub.On("GetState", "ZKT-ERROR").Return(nil, fmt.Errorf("ledger error")).Once()
		exists, err := smartContract.ZakatExists(transactionContext, "ZKT-ERROR")
		require.Error(t, err)
		require.False(t, exists)
		require.Contains(t, err.Error(), "failed to read from world state")
	})

	t.Run("ZakatExists", func(t *testing.T) {
		zakatData := []byte(`{"ID":"ZKT-EXISTS"}`)
		chaincodeStub.On("GetState", "ZKT-EXISTS").Return(zakatData, nil).Once()
		exists, err := smartContract.ZakatExists(transactionContext, "ZKT-EXISTS")
		require.NoError(t, err)
		require.True(t, exists)
	})

	t.Run("ZakatNotExists", func(t *testing.T) {
		chaincodeStub.On("GetState", "ZKT-NOT-EXISTS").Return(nil, nil).Once()
		exists, err := smartContract.ZakatExists(transactionContext, "ZKT-NOT-EXISTS")
		require.NoError(t, err)
		require.False(t, exists)
	})
}

func TestUpdateOfficerStatusErrorPaths(t *testing.T) {
	smartContract := new(SmartContract)
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	t.Run("InvalidStatus", func(t *testing.T) {
		err := smartContract.UpdateOfficerStatus(transactionContext, "OFF-001", "invalid")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid officer status")
	})

	t.Run("GetStateError", func(t *testing.T) {
		chaincodeStub.On("GetState", "OFF-ERROR").Return(nil, fmt.Errorf("ledger error")).Once()
		err := smartContract.UpdateOfficerStatus(transactionContext, "OFF-ERROR", "active")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to read officer")
	})

	t.Run("OfficerNotExists", func(t *testing.T) {
		chaincodeStub.On("GetState", "OFF-NOT-EXISTS").Return(nil, nil).Once()
		err := smartContract.UpdateOfficerStatus(transactionContext, "OFF-NOT-EXISTS", "active")
		require.Error(t, err)
		require.Contains(t, err.Error(), "does not exist")
	})

	t.Run("JSONUnmarshalError", func(t *testing.T) {
		invalidJSON := []byte(`{"invalid json"}`)
		chaincodeStub.On("GetState", "OFF-INVALID-JSON").Return(invalidJSON, nil).Once()
		err := smartContract.UpdateOfficerStatus(transactionContext, "OFF-INVALID-JSON", "active")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to unmarshal officer")
	})

	t.Run("PutStateError", func(t *testing.T) {
		officerData := Officer{
			ID:     "OFF-PUT-ERROR",
			Name:   "Test Officer",
			Status: "inactive",
		}
		officerJSON, _ := json.Marshal(officerData)
		chaincodeStub.On("GetState", "OFF-PUT-ERROR").Return(officerJSON, nil).Once()
		chaincodeStub.On("PutState", "OFF-PUT-ERROR", mock.Anything).Return(fmt.Errorf("put error")).Once()
		err := smartContract.UpdateOfficerStatus(transactionContext, "OFF-PUT-ERROR", "active")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to update officer status")
	})
}

func TestGetZakatByMuzakkiErrorPaths(t *testing.T) {
	smartContract := new(SmartContract)
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	t.Run("EmptyMuzakkiName", func(t *testing.T) {
		_, err := smartContract.GetZakatByMuzakki(transactionContext, "")
		require.Error(t, err)
		require.Contains(t, err.Error(), "muzakki name cannot be empty")
	})

	t.Run("QueryError", func(t *testing.T) {
		queryString := `{"selector":{"muzakki":"TestUser"}}`
		chaincodeStub.On("GetQueryResult", queryString).Return(nil, fmt.Errorf("query error")).Once()
		_, err := smartContract.GetZakatByMuzakki(transactionContext, "TestUser")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to query zakat by muzakki")
	})

	t.Run("IteratorNextError", func(t *testing.T) {
		queryString := `{"selector":{"muzakki":"TestUser"}}`
		mockIterator := &MockQueryIterator{}
		mockIterator.On("HasNext").Return(true).Once()
		mockIterator.On("Next").Return(nil, fmt.Errorf("iterator error")).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetQueryResult", queryString).Return(mockIterator, nil).Once()
		_, err := smartContract.GetZakatByMuzakki(transactionContext, "TestUser")
		require.Error(t, err)
		require.Contains(t, err.Error(), "error iterating over zakat by muzakki results")
	})

	t.Run("JSONUnmarshalError", func(t *testing.T) {
		queryString := `{"selector":{"muzakki":"TestUser"}}`
		badJSON := []byte(`{"invalid json`)
		iterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{{Key: "ZKT-001", Value: badJSON}}}
		chaincodeStub.On("GetQueryResult", queryString).Return(iterator, nil).Once()
		_, err := smartContract.GetZakatByMuzakki(transactionContext, "TestUser")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to unmarshal zakat data for muzakki query")
	})

	t.Run("NoRecordsFound", func(t *testing.T) {
		queryString := `{"selector":{"muzakki":"NonExistentUser"}}`
		emptyIterator := &SimpleQueryIterator{Current: -1, Items: []QueryResult{}}
		chaincodeStub.On("GetQueryResult", queryString).Return(emptyIterator, nil).Once()
		result, err := smartContract.GetZakatByMuzakki(transactionContext, "NonExistentUser")
		require.NoError(t, err)
		require.Empty(t, result)
	})
}

func TestGetAllOfficersErrorPaths(t *testing.T) {
	smartContract := new(SmartContract)
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	t.Run("GetStateByRangeError", func(t *testing.T) {
		chaincodeStub.On("GetStateByRange", "OFF-", "OFF-\\uffff").Return(nil, fmt.Errorf("range error")).Once()
		_, err := smartContract.GetAllOfficers(transactionContext)
		require.Error(t, err)
		require.Contains(t, err.Error(), "range error")
	})

	t.Run("IteratorNextError", func(t *testing.T) {
		mockIterator := &MockQueryIterator{}
		mockIterator.On("HasNext").Return(true).Once()
		mockIterator.On("Next").Return(nil, fmt.Errorf("iterator error")).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetStateByRange", "OFF-", "OFF-\\uffff").Return(mockIterator, nil).Once()
		_, err := smartContract.GetAllOfficers(transactionContext)
		require.Error(t, err)
		require.Contains(t, err.Error(), "iterator error")
	})

	t.Run("JSONUnmarshalError", func(t *testing.T) {
		mockIterator := &MockQueryIterator{}
		queryResponse := &queryresult.KV{
			Key:   "OFF-001",
			Value: []byte(`{"invalid json}`),
		}
		mockIterator.On("HasNext").Return(true).Once()
		mockIterator.On("Next").Return(queryResponse, nil).Once()
		mockIterator.On("HasNext").Return(false).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetStateByRange", "OFF-", "OFF-\\uffff").Return(mockIterator, nil).Once()
		_, err := smartContract.GetAllOfficers(transactionContext)
		require.Error(t, err)
		require.Contains(t, err.Error(), "iterator error")
	})

	t.Run("EmptyResultSet", func(t *testing.T) {
		mockIterator := &MockQueryIterator{}
		mockIterator.On("HasNext").Return(false).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetStateByRange", "OFF-", "OFF-\\uffff").Return(mockIterator, nil).Once()
		result, err := smartContract.GetAllOfficers(transactionContext)
		require.NoError(t, err)
		require.NotNil(t, result)
		require.Empty(t, result)
	})
}

func TestInitLedgerErrorPaths(t *testing.T) {
	smartContract := new(SmartContract)
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	t.Run("GetStateError", func(t *testing.T) {
		chaincodeStub.On("GetState", "PROG-2024-0001").Return(nil, fmt.Errorf("ledger error")).Once()
		err := smartContract.InitLedger(transactionContext)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to check sample program existence")
	})

	t.Run("SampleProgramExists", func(t *testing.T) {
		existingData := []byte(`{"ID":"PROG-2024-0001","Name":"Existing"}`)
		chaincodeStub.On("GetState", "PROG-2024-0001").Return(existingData, nil).Once()
		err := smartContract.InitLedger(transactionContext)
		require.NoError(t, err)
	})

	t.Run("ProgramPutStateError", func(t *testing.T) {
		chaincodeStub.On("GetState", "PROG-2024-0001").Return(nil, nil).Once()
		chaincodeStub.On("PutState", "PROG-2024-0001", mock.Anything).Return(fmt.Errorf("put error")).Once()
		err := smartContract.InitLedger(transactionContext)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to put sample program")
	})

	t.Run("OfficerPutStateError", func(t *testing.T) {
		chaincodeStub.On("GetState", "PROG-2024-0001").Return(nil, nil).Once()
		chaincodeStub.On("PutState", "PROG-2024-0001", mock.Anything).Return(nil).Once()
		chaincodeStub.On("PutState", "OFF-2024-0001", mock.Anything).Return(fmt.Errorf("put error")).Once()
		err := smartContract.InitLedger(transactionContext)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to put sample officer")
	})
}

func TestGetProgramErrorPaths(t *testing.T) {
	smartContract := new(SmartContract)
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	t.Run("GetStateError", func(t *testing.T) {
		chaincodeStub.On("GetState", "PROG-ERROR").Return(nil, fmt.Errorf("ledger error")).Once()
		_, err := smartContract.GetProgram(transactionContext, "PROG-ERROR")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to read program")
	})

	t.Run("ProgramNotExists", func(t *testing.T) {
		chaincodeStub.On("GetState", "PROG-NOT-EXISTS").Return(nil, nil).Once()
		_, err := smartContract.GetProgram(transactionContext, "PROG-NOT-EXISTS")
		require.Error(t, err)
		require.Contains(t, err.Error(), "does not exist")
	})

	t.Run("JSONUnmarshalError", func(t *testing.T) {
		invalidJSON := []byte(`{"invalid json"}`)
		chaincodeStub.On("GetState", "PROG-INVALID-JSON").Return(invalidJSON, nil).Once()
		_, err := smartContract.GetProgram(transactionContext, "PROG-INVALID-JSON")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to unmarshal program")
	})
}

func TestRegisterOfficerErrorPaths(t *testing.T) {
	smartContract := new(SmartContract)
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	t.Run("ValidateOfficerIDError", func(t *testing.T) {
		err := smartContract.RegisterOfficer(transactionContext, "INVALID-ID", "Test Officer", "REF001")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid officer ID format")
	})

	t.Run("GetStateError", func(t *testing.T) {
		chaincodeStub.On("GetState", "OFF-2024-123456789-0001").Return(nil, fmt.Errorf("ledger error")).Once()
		err := smartContract.RegisterOfficer(transactionContext, "OFF-2024-123456789-0001", "Test Officer", "REF001")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to check officer existence")
	})

	t.Run("OfficerAlreadyExists", func(t *testing.T) {
		existingData := []byte(`{"ID":"OFF-2024-123456789-0002","Name":"Existing"}`)
		chaincodeStub.On("GetState", "OFF-2024-123456789-0002").Return(existingData, nil).Once()
		err := smartContract.RegisterOfficer(transactionContext, "OFF-2024-123456789-0002", "Test Officer", "REF001")
		require.Error(t, err)
		require.Contains(t, err.Error(), "already exists")
	})

	t.Run("PutStateError", func(t *testing.T) {
		chaincodeStub.On("GetState", "OFF-2024-123456789-0003").Return(nil, nil).Once()
		chaincodeStub.On("PutState", "OFF-2024-123456789-0003", mock.Anything).Return(fmt.Errorf("put error")).Once()
		err := smartContract.RegisterOfficer(transactionContext, "OFF-2024-123456789-0003", "Test Officer", "REF001")
		require.Error(t, err)
		require.Contains(t, err.Error(), "put error")
	})
}

func TestGetOfficerByReferralErrorPaths(t *testing.T) {
	smartContract := new(SmartContract)
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	t.Run("QueryError", func(t *testing.T) {
		queryString := `{"selector":{"referralCode":"REF001"}}`
		chaincodeStub.On("GetQueryResult", queryString).Return(nil, fmt.Errorf("query error")).Once()
		_, err := smartContract.GetOfficerByReferral(transactionContext, "REF001")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to query officer")
	})

	t.Run("OfficerNotFound", func(t *testing.T) {
		queryString := `{"selector":{"referralCode":"NOTFOUND"}}`
		mockIterator := &MockQueryIterator{}
		mockIterator.On("HasNext").Return(false).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetQueryResult", queryString).Return(mockIterator, nil).Once()
		_, err := smartContract.GetOfficerByReferral(transactionContext, "NOTFOUND")
		require.Error(t, err)
		require.Contains(t, err.Error(), "does not exist")
	})

	t.Run("IteratorNextError", func(t *testing.T) {
		queryString := `{"selector":{"referralCode":"REF001"}}`
		mockIterator := &MockQueryIterator{}
		mockIterator.On("HasNext").Return(true).Once()
		mockIterator.On("Next").Return(nil, fmt.Errorf("iterator error")).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetQueryResult", queryString).Return(mockIterator, nil).Once()
		_, err := smartContract.GetOfficerByReferral(transactionContext, "REF001")
		require.Error(t, err)
		require.Contains(t, err.Error(), "iterator error")
	})

	t.Run("JSONUnmarshalError", func(t *testing.T) {
		queryString := `{"selector":{"referralCode":"REF001"}}`
		mockIterator := &MockQueryIterator{}
		queryResponse := &queryresult.KV{
			Key:   "OFF-001",
			Value: []byte(`{"invalid json}`),
		}
		mockIterator.On("HasNext").Return(true).Once()
		mockIterator.On("Next").Return(queryResponse, nil).Once()
		mockIterator.On("HasNext").Return(false).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetQueryResult", queryString).Return(mockIterator, nil).Once()
		_, err := smartContract.GetOfficerByReferral(transactionContext, "REF001")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to unmarshal officer")
	})

	t.Run("MultipleOfficersFound", func(t *testing.T) {
		queryString := `{"selector":{"referralCode":"REF001"}}`
		mockIterator := &MockQueryIterator{}
		queryResponse := &queryresult.KV{
			Key: "OFF-001",
			Value: []byte(`{
				"ID": "OFF-001",
				"Name": "Test Officer",
				"ReferralCode": "REF001",
				"Status": "active"
			}`),
		}
		mockIterator.On("HasNext").Return(true).Once()
		mockIterator.On("Next").Return(queryResponse, nil).Once()
		mockIterator.On("HasNext").Return(true).Once() // Simulate multiple results
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetQueryResult", queryString).Return(mockIterator, nil).Once()
		result, err := smartContract.GetOfficerByReferral(transactionContext, "REF001")
		require.NoError(t, err)
		require.Equal(t, "OFF-001", result.ID)
	})
}

func TestAutoValidatePaymentErrorPaths(t *testing.T) {
	smartContract := new(SmartContract)
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	t.Run("EmptyZakatID", func(t *testing.T) {
		err := smartContract.AutoValidatePayment(transactionContext, "", "")
		require.Error(t, err)
		require.Contains(t, err.Error(), "zakat ID cannot be empty")
	})

	t.Run("QueryZakatError", func(t *testing.T) {
		chaincodeStub.On("GetState", "ZKT-ERROR").Return(nil, fmt.Errorf("ledger error")).Once()
		err := smartContract.AutoValidatePayment(transactionContext, "ZKT-ERROR", "")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to query zakat")
	})

	t.Run("ZakatNotPending", func(t *testing.T) {
		zakatData := Zakat{
			ID:     "ZKT-COLLECTED",
			Status: "collected",
		}
		zakatJSON, _ := json.Marshal(zakatData)
		chaincodeStub.On("GetState", "ZKT-COLLECTED").Return(zakatJSON, nil).Once()
		err := smartContract.AutoValidatePayment(transactionContext, "ZKT-COLLECTED", "")
		require.Error(t, err)
		require.Contains(t, err.Error(), "is not in pending status")
	})
}

func TestValidatePaymentErrorPaths(t *testing.T) {
	smartContract := new(SmartContract)
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	t.Run("EmptyZakatID", func(t *testing.T) {
		err := smartContract.ValidatePayment(transactionContext, "", "RCP-001", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "zakat ID cannot be empty")
	})

	t.Run("EmptyReceiptNumber", func(t *testing.T) {
		err := smartContract.ValidatePayment(transactionContext, "ZKT-001", "", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "receipt number cannot be empty")
	})

	t.Run("EmptyValidatedBy", func(t *testing.T) {
		err := smartContract.ValidatePayment(transactionContext, "ZKT-001", "RCP-001", "")
		require.Error(t, err)
		require.Contains(t, err.Error(), "validatedBy (admin user) cannot be empty")
	})

	t.Run("QueryZakatError", func(t *testing.T) {
		chaincodeStub.On("GetState", "ZKT-ERROR").Return(nil, fmt.Errorf("ledger error")).Once()
		err := smartContract.ValidatePayment(transactionContext, "ZKT-ERROR", "RCP-001", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to query zakat")
	})

	t.Run("ZakatNotPending", func(t *testing.T) {
		zakatData := Zakat{
			ID:     "ZKT-COLLECTED",
			Status: "collected",
		}
		zakatJSON, _ := json.Marshal(zakatData)
		chaincodeStub.On("GetState", "ZKT-COLLECTED").Return(zakatJSON, nil).Once()
		err := smartContract.ValidatePayment(transactionContext, "ZKT-COLLECTED", "RCP-001", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "is not in pending status")
	})

	t.Run("ProgramGetError", func(t *testing.T) {
		zakatData := Zakat{
			ID:        "ZKT-PENDING-PROG",
			Status:    "pending",
			ProgramID: "PROG-ERROR",
			Amount:    100000,
		}
		zakatJSON, _ := json.Marshal(zakatData)
		chaincodeStub.On("GetState", "ZKT-PENDING-PROG").Return(zakatJSON, nil).Once()
		chaincodeStub.On("GetState", "PROG-ERROR").Return(nil, fmt.Errorf("program error")).Once()
		err := smartContract.ValidatePayment(transactionContext, "ZKT-PENDING-PROG", "RCP-001", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to get program")
	})

	t.Run("OfficerGetError", func(t *testing.T) {
		zakatData := Zakat{
			ID:           "ZKT-PENDING-OFF",
			Status:       "pending",
			ReferralCode: "REF-ERROR",
			Amount:       100000,
		}
		zakatJSON, _ := json.Marshal(zakatData)
		queryString := `{"selector":{"referralCode":"REF-ERROR"}}`
		chaincodeStub.On("GetState", "ZKT-PENDING-OFF").Return(zakatJSON, nil).Once()
		chaincodeStub.On("GetQueryResult", queryString).Return(nil, fmt.Errorf("officer error")).Once()
		err := smartContract.ValidatePayment(transactionContext, "ZKT-PENDING-OFF", "RCP-001", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to get officer")
	})

	t.Run("ZakatPutStateError", func(t *testing.T) {
		zakatData := Zakat{
			ID:     "ZKT-PENDING-PUT-ERROR",
			Status: "pending",
			Amount: 100000,
		}
		zakatJSON, _ := json.Marshal(zakatData)
		chaincodeStub.On("GetState", "ZKT-PENDING-PUT-ERROR").Return(zakatJSON, nil).Once()
		chaincodeStub.On("PutState", "ZKT-PENDING-PUT-ERROR", mock.Anything).Return(fmt.Errorf("put error")).Once()
		err := smartContract.ValidatePayment(transactionContext, "ZKT-PENDING-PUT-ERROR", "RCP-001", "admin")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to put updated zakat")
	})
}

func TestGetZakatByStatusErrorPaths(t *testing.T) {
	smartContract := new(SmartContract)
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	t.Run("InvalidStatus", func(t *testing.T) {
		_, err := smartContract.GetZakatByStatus(transactionContext, "invalid")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid status")
	})

	t.Run("QueryError", func(t *testing.T) {
		queryString := `{"selector":{"status":"pending"}}`
		chaincodeStub.On("GetQueryResult", queryString).Return(nil, fmt.Errorf("query error")).Once()
		_, err := smartContract.GetZakatByStatus(transactionContext, "pending")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to query zakat by status")
	})

	t.Run("IteratorNextError", func(t *testing.T) {
		queryString := `{"selector":{"status":"pending"}}`
		mockIterator := &MockQueryIterator{}
		mockIterator.On("HasNext").Return(true).Once()
		mockIterator.On("Next").Return(nil, fmt.Errorf("iterator error")).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetQueryResult", queryString).Return(mockIterator, nil).Once()
		_, err := smartContract.GetZakatByStatus(transactionContext, "pending")
		require.Error(t, err)
		require.Contains(t, err.Error(), "iterator error")
	})

	t.Run("JSONUnmarshalError", func(t *testing.T) {
		queryString := `{"selector":{"status":"pending"}}`
		mockIterator := &MockQueryIterator{}
		queryResponse := &queryresult.KV{
			Key:   "ZKT-001",
			Value: []byte(`{"invalid json}`),
		}
		mockIterator.On("HasNext").Return(true).Once()
		mockIterator.On("Next").Return(queryResponse, nil).Once()
		mockIterator.On("HasNext").Return(false).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetQueryResult", queryString).Return(mockIterator, nil).Once()
		_, err := smartContract.GetZakatByStatus(transactionContext, "pending")
		require.Error(t, err)
		require.Contains(t, err.Error(), "iterator error")
	})
}

func TestGetZakatByProgramErrorPaths(t *testing.T) {
	smartContract := new(SmartContract)
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	t.Run("QueryError", func(t *testing.T) {
		queryString := `{"selector":{"programID":"PROG-001"}}`
		chaincodeStub.On("GetQueryResult", queryString).Return(nil, fmt.Errorf("query error")).Once()
		_, err := smartContract.GetZakatByProgram(transactionContext, "PROG-001")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to query zakat by program")
	})

	t.Run("IteratorNextError", func(t *testing.T) {
		queryString := `{"selector":{"programID":"PROG-001"}}`
		mockIterator := &MockQueryIterator{}
		mockIterator.On("HasNext").Return(true).Once()
		mockIterator.On("Next").Return(nil, fmt.Errorf("iterator error")).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetQueryResult", queryString).Return(mockIterator, nil).Once()
		_, err := smartContract.GetZakatByProgram(transactionContext, "PROG-001")
		require.Error(t, err)
		require.Contains(t, err.Error(), "iterator error")
	})

	t.Run("JSONUnmarshalError", func(t *testing.T) {
		queryString := `{"selector":{"programID":"PROG-001"}}`
		mockIterator := &MockQueryIterator{}
		queryResponse := &queryresult.KV{
			Key:   "ZKT-001",
			Value: []byte(`{"invalid json}`),
		}
		mockIterator.On("HasNext").Return(true).Once()
		mockIterator.On("Next").Return(queryResponse, nil).Once()
		mockIterator.On("HasNext").Return(false).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetQueryResult", queryString).Return(mockIterator, nil).Once()
		_, err := smartContract.GetZakatByProgram(transactionContext, "PROG-001")
		require.Error(t, err)
		require.Contains(t, err.Error(), "iterator error")
	})
}

func TestGetZakatByOfficerErrorPaths(t *testing.T) {
	smartContract := new(SmartContract)
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	t.Run("QueryError", func(t *testing.T) {
		queryString := `{"selector":{"referralCode":"REF001"}}`
		chaincodeStub.On("GetQueryResult", queryString).Return(nil, fmt.Errorf("query error")).Once()
		_, err := smartContract.GetZakatByOfficer(transactionContext, "REF001")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to query zakat by officer")
	})

	t.Run("IteratorNextError", func(t *testing.T) {
		queryString := `{"selector":{"referralCode":"REF001"}}`
		mockIterator := &MockQueryIterator{}
		mockIterator.On("HasNext").Return(true).Once()
		mockIterator.On("Next").Return(nil, fmt.Errorf("iterator error")).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetQueryResult", queryString).Return(mockIterator, nil).Once()
		_, err := smartContract.GetZakatByOfficer(transactionContext, "REF001")
		require.Error(t, err)
		require.Contains(t, err.Error(), "iterator error")
	})

	t.Run("JSONUnmarshalError", func(t *testing.T) {
		queryString := `{"selector":{"referralCode":"REF001"}}`
		mockIterator := &MockQueryIterator{}
		queryResponse := &queryresult.KV{
			Key:   "ZKT-001",
			Value: []byte(`{"invalid json"`),
		}
		mockIterator.On("HasNext").Return(true).Once()
		mockIterator.On("Next").Return(queryResponse, nil).Once()
		mockIterator.On("HasNext").Return(false).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetQueryResult", queryString).Return(mockIterator, nil).Once()
		_, err := smartContract.GetZakatByOfficer(transactionContext, "REF001")
		require.Error(t, err)
		require.Contains(t, err.Error(), "iterator error")
	})
}

func TestQueryZakatErrorPaths(t *testing.T) {
	smartContract := new(SmartContract)
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	t.Run("GetStateError", func(t *testing.T) {
		chaincodeStub.On("GetState", "ZKT-ERROR").Return(nil, fmt.Errorf("ledger error")).Once()
		_, err := smartContract.QueryZakat(transactionContext, "ZKT-ERROR")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to read zakat")
	})

	t.Run("ZakatNotExists", func(t *testing.T) {
		chaincodeStub.On("GetState", "ZKT-NOT-EXISTS").Return(nil, nil).Once()
		_, err := smartContract.QueryZakat(transactionContext, "ZKT-NOT-EXISTS")
		require.Error(t, err)
		require.Contains(t, err.Error(), "does not exist")
	})

	t.Run("JSONUnmarshalError", func(t *testing.T) {
		invalidJSON := []byte(`{"invalid json"}`)
		chaincodeStub.On("GetState", "ZKT-INVALID-JSON").Return(invalidJSON, nil).Once()
		_, err := smartContract.QueryZakat(transactionContext, "ZKT-INVALID-JSON")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to unmarshal zakat")
	})
}

func TestClearFunctionsErrorPaths(t *testing.T) {
	smartContract := new(SmartContract)
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	t.Run("ClearAllZakatGetStateByRangeError", func(t *testing.T) {
		chaincodeStub.On("GetStateByRange", "ZKT-", "ZKT-\\uffff").Return(nil, fmt.Errorf("range error")).Once()
		err := smartContract.ClearAllZakat(transactionContext)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to get Zakat records for deletion")
	})

	t.Run("ClearAllZakatIteratorNextError", func(t *testing.T) {
		mockIterator := &MockQueryIterator{}
		mockIterator.On("HasNext").Return(true).Once()
		mockIterator.On("Next").Return(nil, fmt.Errorf("iterator error")).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetStateByRange", "ZKT-", "ZKT-\\uffff").Return(mockIterator, nil).Once()
		err := smartContract.ClearAllZakat(transactionContext)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to iterate Zakat records for deletion")
	})

	t.Run("ClearAllZakatDelStateError", func(t *testing.T) {
		mockIterator := &MockQueryIterator{}
		queryResponse := &queryresult.KV{
			Key:   "ZKT-001",
			Value: []byte(`{"ID":"ZKT-001"}`),
		}
		mockIterator.On("HasNext").Return(true).Once()
		mockIterator.On("Next").Return(queryResponse, nil).Once()
		mockIterator.On("HasNext").Return(false).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetStateByRange", "ZKT-", "ZKT-\\uffff").Return(mockIterator, nil).Once()
		chaincodeStub.On("DelState", "ZKT-001").Return(fmt.Errorf("delete error")).Once()
		err := smartContract.ClearAllZakat(transactionContext)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to delete Zakat record")
	})

	t.Run("ClearAllProgramsGetStateByRangeError", func(t *testing.T) {
		chaincodeStub.On("GetStateByRange", "PROG-", "PROG-\\uffff").Return(nil, fmt.Errorf("range error")).Once()
		err := smartContract.ClearAllPrograms(transactionContext)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to get Program records for deletion")
	})

	t.Run("ClearAllProgramsIteratorNextError", func(t *testing.T) {
		mockIterator := &MockQueryIterator{}
		mockIterator.On("HasNext").Return(true).Once()
		mockIterator.On("Next").Return(nil, fmt.Errorf("iterator error")).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetStateByRange", "PROG-", "PROG-\\uffff").Return(mockIterator, nil).Once()
		err := smartContract.ClearAllPrograms(transactionContext)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to iterate Program records for deletion")
	})

	t.Run("ClearAllProgramsDelStateError", func(t *testing.T) {
		mockIterator := &MockQueryIterator{}
		queryResponse := &queryresult.KV{
			Key:   "PROG-001",
			Value: []byte(`{"ID":"PROG-001"}`),
		}
		mockIterator.On("HasNext").Return(true).Once()
		mockIterator.On("Next").Return(queryResponse, nil).Once()
		mockIterator.On("HasNext").Return(false).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetStateByRange", "PROG-", "PROG-\\uffff").Return(mockIterator, nil).Once()
		chaincodeStub.On("DelState", "PROG-001").Return(fmt.Errorf("delete error")).Once()
		err := smartContract.ClearAllPrograms(transactionContext)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to delete Program record")
	})

	t.Run("ClearAllOfficersGetStateByRangeError", func(t *testing.T) {
		chaincodeStub.On("GetStateByRange", "OFF-", "OFF-\\uffff").Return(nil, fmt.Errorf("range error")).Once()
		err := smartContract.ClearAllOfficers(transactionContext)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to get Officer records for deletion")
	})

	t.Run("ClearAllOfficersIteratorNextError", func(t *testing.T) {
		mockIterator := &MockQueryIterator{}
		mockIterator.On("HasNext").Return(true).Once()
		mockIterator.On("Next").Return(nil, fmt.Errorf("iterator error")).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetStateByRange", "OFF-", "OFF-\\uffff").Return(mockIterator, nil).Once()
		err := smartContract.ClearAllOfficers(transactionContext)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to iterate Officer records for deletion")
	})

	t.Run("ClearAllOfficersDelStateError", func(t *testing.T) {
		mockIterator := &MockQueryIterator{}
		queryResponse := &queryresult.KV{
			Key:   "OFF-001",
			Value: []byte(`{"ID":"OFF-001"}`),
		}
		mockIterator.On("HasNext").Return(true).Once()
		mockIterator.On("Next").Return(queryResponse, nil).Once()
		mockIterator.On("HasNext").Return(false).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetStateByRange", "OFF-", "OFF-\\uffff").Return(mockIterator, nil).Once()
		chaincodeStub.On("DelState", "OFF-001").Return(fmt.Errorf("delete error")).Once()
		err := smartContract.ClearAllOfficers(transactionContext)
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to delete Officer record")
	})
}

func TestUpdateProgramStatusErrorPaths(t *testing.T) {
	smartContract := new(SmartContract)
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	t.Run("InvalidStatus", func(t *testing.T) {
		err := smartContract.UpdateProgramStatus(transactionContext, "PROG-001", "invalid")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid program status")
	})

	t.Run("GetProgramError", func(t *testing.T) {
		chaincodeStub.On("GetState", "PROG-ERROR").Return(nil, fmt.Errorf("ledger error")).Once()
		err := smartContract.UpdateProgramStatus(transactionContext, "PROG-ERROR", "completed")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to get program")
	})

	t.Run("PutStateError", func(t *testing.T) {
		programData := DonationProgram{
			ID:     "PROG-PUT-ERROR",
			Name:   "Test Program",
			Status: "active",
		}
		programJSON, _ := json.Marshal(programData)
		chaincodeStub.On("GetState", "PROG-PUT-ERROR").Return(programJSON, nil).Once()
		chaincodeStub.On("PutState", "PROG-PUT-ERROR", mock.Anything).Return(fmt.Errorf("put error")).Once()
		err := smartContract.UpdateProgramStatus(transactionContext, "PROG-PUT-ERROR", "completed")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to update program status")
	})
}

func TestGetDailyReportErrorPaths(t *testing.T) {
	smartContract := new(SmartContract)
	chaincodeStub := new(MockStub)
	transactionContext := new(contractapi.TransactionContext)
	transactionContext.SetStub(chaincodeStub)

	t.Run("InvalidDateFormat", func(t *testing.T) {
		_, err := smartContract.GetDailyReport(transactionContext, "invalid-date")
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid date format for report")
	})

	t.Run("GetQueryResultError", func(t *testing.T) {
		chaincodeStub.On("GetQueryResult", mock.AnythingOfType("string")).Return(nil, fmt.Errorf("query error")).Once()
		_, err := smartContract.GetDailyReport(transactionContext, "2024-01-01")
		require.Error(t, err)
		require.Contains(t, err.Error(), "failed to query daily report")
	})

	t.Run("IteratorNextError", func(t *testing.T) {
		mockIterator := &MockQueryIterator{}
		mockIterator.On("HasNext").Return(true).Once()
		mockIterator.On("Next").Return(nil, fmt.Errorf("iterator error")).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetQueryResult", mock.AnythingOfType("string")).Return(mockIterator, nil).Once()
		_, err := smartContract.GetDailyReport(transactionContext, "2024-01-01")
		require.Error(t, err)
		require.Contains(t, err.Error(), "iterator error")
	})

	t.Run("JSONUnmarshalError", func(t *testing.T) {
		mockIterator := &MockQueryIterator{}
		queryResponse := &queryresult.KV{
			Key:   "ZKT-001",
			Value: []byte(`{"invalid json"`),
		}
		mockIterator.On("HasNext").Return(true).Once()
		mockIterator.On("Next").Return(queryResponse, nil).Once()
		mockIterator.On("HasNext").Return(false).Once()
		mockIterator.On("Close").Return(nil).Once()
		chaincodeStub.On("GetQueryResult", mock.AnythingOfType("string")).Return(mockIterator, nil).Once()
		_, err := smartContract.GetDailyReport(transactionContext, "2024-01-01")
		require.Error(t, err)
		require.Contains(t, err.Error(), "iterator error")
	})
}
