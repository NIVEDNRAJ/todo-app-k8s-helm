import { Component, OnInit, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatDialog, MatDialogModule } from '@angular/material/dialog';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatTooltipModule } from '@angular/material/tooltip';
import { AuthService } from '../../services/auth.service';
import { TodoService } from '../../services/todo.service';
import { Todo } from '../../models/todo.model';
import { TodoDialogComponent } from '../todo-dialog/todo-dialog.component';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [
    CommonModule,
    MatIconModule,
    MatButtonModule,
    MatDialogModule,
    MatProgressSpinnerModule,
    MatTooltipModule
  ],
  templateUrl: './dashboard.component.html',
  styleUrl: './dashboard.component.scss'
})
export class DashboardComponent implements OnInit {
  todos = signal<Todo[]>([]);
  totalCount = signal(0);
  pageNumber = signal(1);
  pageSize = signal(6);
  searchText = signal('');
  completedFilter = signal<boolean | undefined>(undefined);

  isLoading = signal(false);
  userName = computed(() => this.authService.currentUser()?.name || 'User');
  totalPages = computed(() => Math.ceil(this.totalCount() / this.pageSize()) || 1);

  constructor(
    private authService: AuthService,
    private todoService: TodoService,
    private dialog: MatDialog
  ) {}

  ngOnInit(): void {
    this.loadTodos();
  }

  loadTodos(): void {
    this.isLoading.set(true);
    this.todoService.getPaged(
      this.searchText(),
      this.completedFilter(),
      this.pageNumber(),
      this.pageSize()
    ).subscribe({
      next: (result) => {
        this.todos.set(result.items);
        this.totalCount.set(result.totalCount);
        this.isLoading.set(false);
      },
      error: () => {
        this.isLoading.set(false);
      }
    });
  }

  onSearch(event: Event): void {
    const input = event.target as HTMLInputElement;
    this.searchText.set(input.value);
    this.pageNumber.set(1);
    this.loadTodos();
  }

  setFilter(filter: boolean | undefined): void {
    this.completedFilter.set(filter);
    this.pageNumber.set(1);
    this.loadTodos();
  }

  prevPage(): void {
    if (this.pageNumber() > 1) {
      this.pageNumber.update(p => p - 1);
      this.loadTodos();
    }
  }

  nextPage(): void {
    if (this.pageNumber() < this.totalPages()) {
      this.pageNumber.update(p => p + 1);
      this.loadTodos();
    }
  }

  openAddDialog(): void {
    const dialogRef = this.dialog.open(TodoDialogComponent, {
      width: '450px',
      data: {}
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        this.todoService.create(result).subscribe({
          next: () => this.loadTodos()
        });
      }
    });
  }

  openEditDialog(todo: Todo): void {
    const dialogRef = this.dialog.open(TodoDialogComponent, {
      width: '450px',
      data: { todo }
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        const updateRequest = {
          title: result.title,
          description: result.description,
          isCompleted: todo.isCompleted
        };
        this.todoService.update(todo.id, updateRequest).subscribe({
          next: () => this.loadTodos()
        });
      }
    });
  }

  toggleComplete(todo: Todo): void {
    const updateRequest = {
      title: todo.title,
      description: todo.description,
      isCompleted: !todo.isCompleted
    };
    
    this.todos.update(items => 
      items.map(t => t.id === todo.id ? { ...t, isCompleted: !t.isCompleted } : t)
    );

    this.todoService.update(todo.id, updateRequest).subscribe({
      error: () => this.loadTodos()
    });
  }

  deleteTodo(todoId: number): void {
    if (confirm('Are you sure you want to delete this task?')) {
      this.todoService.delete(todoId).subscribe({
        next: () => this.loadTodos()
      });
    }
  }

  logout(): void {
    this.authService.logout();
  }
}
