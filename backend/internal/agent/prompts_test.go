package agent

import (
	"strings"
	"testing"
)

// Both prompts are baked in as constants so OpenAI's prompt cache can hit on
// the prefix. These tests guard against accidental edits — if you change a
// prompt, update the expected prefix here in the same commit so the change is
// explicit in code review.

func TestChatSystemPromptStable(t *testing.T) {
	if len(chatSystemPrompt) == 0 {
		t.Fatal("chatSystemPrompt is empty")
	}
	const wantPrefix = "You are a fitness assistant"
	if !strings.HasPrefix(chatSystemPrompt, wantPrefix) {
		t.Errorf("chat prompt prefix changed; want %q, got %q", wantPrefix, chatSystemPrompt[:len(wantPrefix)])
	}
}

func TestCoachSystemPromptCoversKeyConcepts(t *testing.T) {
	if len(coachSystemPrompt) == 0 {
		t.Fatal("coachSystemPrompt is empty")
	}
	for _, want := range []string{
		"Coach",
		"propose_programme",
		"search_exercises",
		"Days per week",
		"Experience",
	} {
		if !strings.Contains(coachSystemPrompt, want) {
			t.Errorf("coach prompt missing %q", want)
		}
	}
}
