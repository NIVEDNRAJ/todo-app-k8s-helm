import { Component, Inject, signal } from '@angular/core';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';
import { MatDialogRef, MAT_DIALOG_DATA, MatDialogModule } from '@angular/material/dialog';
import { CommonModule } from '@angular/common';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { Todo } from '../../models/todo.model';

@Component({
  selector: 'app-todo-dialog',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    MatDialogModule,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule
  ],
  templateUrl: './todo-dialog.component.html',
  styleUrl: './todo-dialog.component.scss'
})
export class TodoDialogComponent {
  todoForm: FormGroup;
  isEditMode = signal(false);

  constructor(
    private fb: FormBuilder,
    public dialogRef: MatDialogRef<TodoDialogComponent>,
    @Inject(MAT_DIALOG_DATA) public data: { todo?: Todo }
  ) {
    this.isEditMode.set(!!data?.todo);
    this.todoForm = this.fb.group({
      title: [data?.todo?.title || '', [Validators.required, Validators.maxLength(200)]],
      description: [data?.todo?.description || '', [Validators.maxLength(1000)]]
    });
  }

  onSubmit(): void {
    if (this.todoForm.invalid) {
      return;
    }
    this.dialogRef.close(this.todoForm.value);
  }

  onCancel(): void {
    this.dialogRef.close();
  }
}
