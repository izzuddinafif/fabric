package services

import (
	"crypto/tls"
	"fmt"

	"github.com/izzuddinafif/fabric/platform/backend/internal/config"
	"gopkg.in/gomail.v2"
)

// EmailService handles email notifications
type EmailService struct {
	config config.EmailConfig
}

// NewEmailService creates a new email service
func NewEmailService(cfg config.EmailConfig) *EmailService {
	return &EmailService{
		config: cfg,
	}
}

// SendEmail sends an email
func (s *EmailService) SendEmail(to, subject, body string) error {
	if s.config.Username == "" || s.config.Password == "" {
		// Email not configured, skip sending
		return nil
	}

	m := gomail.NewMessage()
	m.SetHeader("From", s.config.Username)
	m.SetHeader("To", to)
	m.SetHeader("Subject", subject)
	m.SetBody("text/plain", body)

	d := gomail.NewDialer(s.config.SMTPHost, s.config.SMTPPort, s.config.Username, s.config.Password)
	d.TLSConfig = &tls.Config{InsecureSkipVerify: true}

	if err := d.DialAndSend(m); err != nil {
		return fmt.Errorf("failed to send email: %w", err)
	}

	return nil
}

// SendDonationSubmittedEmail sends notification when donation is submitted
func (s *EmailService) SendDonationSubmittedEmail(donorEmail, donorName, donationID string, amount float64) error {
	subject := "Donasi Zakat Berhasil Diterima"
	body := fmt.Sprintf(`
Assalamu'alaikum %s,

Terima kasih atas donasi zakat Anda.
Detail donasi:
- ID Donasi: %s
- Jumlah: Rp %.2f
- Status: Menunggu Validasi

Donasi Anda akan divalidasi dalam 30 detik.

Barakallahu fiikum,
YDSF Platform
`, donorName, donationID, amount)

	return s.SendEmail(donorEmail, subject, body)
}

// SendDonationValidatedEmail sends notification when donation is validated
func (s *EmailService) SendDonationValidatedEmail(donorEmail, donorName, donationID string, amount float64) error {
	subject := "Donasi Zakat Telah Divalidasi"
	body := fmt.Sprintf(`
Assalamu'alaikum %s,

Donasi zakat Anda telah berhasil divalidasi.
Detail donasi:
- ID Donasi: %s
- Jumlah: Rp %.2f
- Status: Tervalidasi

Jazakallahu khairan atas kontribusi Anda.

Barakallahu fiikum,
YDSF Platform
`, donorName, donationID, amount)

	return s.SendEmail(donorEmail, subject, body)
}
