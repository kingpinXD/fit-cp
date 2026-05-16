package main

import "testing"

func TestNormalize(t *testing.T) {
	cases := []struct {
		in       string
		wantName string
		wantDesc string
		wantOK   bool
	}{
		{"Flat DB Press (Heavy)", "Flat DB Press", "Heavy", true},
		{"Flat DB Press (Back off)", "Flat DB Press", "Back off", true},
		{"Seated Cable Row 10-12 (dropset)", "Seated Cable Row 10-12", "dropset", true},
		{"A1: EZ Bar Skull Crusher", "EZ Bar Skull Crusher", "", true},
		{"B2: DB Curl", "DB Curl", "", true},
		{"Back Squat [or front squat]", "Back Squat", "", true},
		{"Hack Squat (Heavy) (AMRAP)", "Hack Squat", "AMRAP", true},
		{"   Pullup   ", "Pullup", "", true},
		{"", "", "", false},
		{"Exercise", "", "", false},
		{"Substitution Option 1", "", "", false},
		{"Suggested 1-2 Rest Days", "", "", false},
		{"123", "", "", false},
	}
	for _, tc := range cases {
		got, ok := normalize(tc.in)
		if ok != tc.wantOK {
			t.Errorf("normalize(%q) ok = %v, want %v", tc.in, ok, tc.wantOK)
			continue
		}
		if !ok {
			continue
		}
		if got.name != tc.wantName {
			t.Errorf("normalize(%q) name = %q, want %q", tc.in, got.name, tc.wantName)
		}
		if got.description != tc.wantDesc {
			t.Errorf("normalize(%q) desc = %q, want %q", tc.in, got.description, tc.wantDesc)
		}
	}
}

func TestSourceSlug(t *testing.T) {
	cases := []struct {
		in   string
		want string
	}{
		{"/x/The Essentials Program 4x.xlsx", "jn_essentials_4x"},
		{"/x/The Essentials Program.xlsx", "jn_essentials"},
		{"/x/ULTIMATE PPL/The_Ultimate_Push_Pull_Legs_System_-_5x.xlsx", "jn_ppl_5x"},
		{"/x/Edited PPL 5x.xlsx", "jn_ppl_edited_5x"},
	}
	for _, tc := range cases {
		got := sourceSlug(tc.in)
		if got != tc.want {
			t.Errorf("sourceSlug(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}
