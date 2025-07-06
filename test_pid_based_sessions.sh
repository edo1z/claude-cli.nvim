#!/bin/bash

# テスト用スクリプト：PIDベースのセッション名が正しく動作することを確認

echo "=== Claude CLI PIDベースセッション名テスト ==="
echo ""

# 現在のPIDを表示
CURRENT_PID=$$
echo "現在のシェルPID: $CURRENT_PID"
echo ""

# テスト1: 同じプロセスから複数のセッションを作成
echo "テスト1: 同じプロセスから複数のセッションを作成"
tmux new-session -d -s "claude_${CURRENT_PID}_1" 'echo "Session 1"'
tmux new-session -d -s "claude_${CURRENT_PID}_2" 'echo "Session 2"'
tmux new-session -d -s "claude_${CURRENT_PID}_3" 'echo "Session 3"'

echo "作成されたセッション:"
tmux list-sessions | grep "claude_${CURRENT_PID}_"
echo ""

# テスト2: 別のPIDのセッションを作成（シミュレート）
echo "テスト2: 別のPIDのセッションを作成（シミュレート）"
FAKE_PID=99999
tmux new-session -d -s "claude_${FAKE_PID}_1" 'echo "Other Process Session"'

echo "全てのclaudeセッション:"
tmux list-sessions | grep "^claude_"
echo ""

# テスト3: 特定のPIDのセッションのみをリスト
echo "テスト3: 現在のPID (${CURRENT_PID}) のセッションのみをリスト"
tmux list-sessions | grep "^claude_${CURRENT_PID}_"
echo ""

# クリーンアップ
echo "クリーンアップ中..."
tmux kill-session -t "claude_${CURRENT_PID}_1" 2>/dev/null
tmux kill-session -t "claude_${CURRENT_PID}_2" 2>/dev/null
tmux kill-session -t "claude_${CURRENT_PID}_3" 2>/dev/null
tmux kill-session -t "claude_${FAKE_PID}_1" 2>/dev/null

echo "テスト完了！"